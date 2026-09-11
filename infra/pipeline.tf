# GitHub is the source of truth (the app repo lives there — CodeCommit
# was only ever a mirror the old pipeline read from, and AWS stopped
# onboarding new CodeCommit customers in 2024). CodeStarSourceConnection
# replaces that mirror step: CodePipeline reads directly from GitHub via
# an AWS-managed GitHub App install, no repo duplication.
#
# Caveat Terraform can't paper over: a connection Terraform creates comes
# up in status PENDING. Completing the GitHub App OAuth handshake is a
# manual step in the CodePipeline console (Settings > Connections >
# "Update pending connection") — there is no CLI/API way to finish it.
# Do this once, by hand, before the pipeline's first run.
resource "aws_codestarconnections_connection" "github" {
  name          = "appointments-github"
  provider_type = "GitHub"
}

# --- Pipeline artifact bucket ---

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "appointments-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # build artifacts, not state — safe to nuke on teardown
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket                  = aws_s3_bucket.pipeline_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- CodeBuild log groups (explicit, so the IAM policies below can be
# scoped to a specific ARN instead of a wildcard log group) ---

resource "aws_cloudwatch_log_group" "codebuild_unittest" {
  name              = "/appointments/codebuild/unittest"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "codebuild_buildimage" {
  name              = "/appointments/codebuild/buildimage"
  retention_in_days = 30
}

# --- IAM: CodeBuild service roles ---

resource "aws_iam_role" "codebuild_unittest" {
  name = "appointments-codebuild-unittest-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_unittest" {
  name = "codebuild-unittest-scoped"
  role = aws_iam_role.codebuild_unittest.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.codebuild_unittest.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      },
    ]
  })
}

resource "aws_iam_role" "codebuild_buildimage" {
  name = "appointments-codebuild-buildimage-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_buildimage" {
  name = "codebuild-buildimage-scoped"
  role = aws_iam_role.codebuild_buildimage.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.codebuild_buildimage.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*" # same no-resource-scoping exception as iam.tf's app_ecr_pull policy
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = aws_ecr_repository.app.arn
      },
    ]
  })
}

# --- CodeBuild projects ---

resource "aws_codebuild_project" "unittest" {
  name         = "appointments-unittest"
  service_role = aws_iam_role.codebuild_unittest.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild_unittest.name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspecs/buildspec_unittest.yml"
  }
}

resource "aws_codebuild_project" "buildimage" {
  name         = "appointments-buildimage"
  service_role = aws_iam_role.codebuild_buildimage.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true # required: this stage runs `docker build`
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild_buildimage.name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspecs/buildspec_buildimage.yml"
  }
}

# --- IAM: CodePipeline service role ---

resource "aws_iam_role" "codepipeline" {
  name = "appointments-codepipeline-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "codepipeline-scoped"
  role = aws_iam_role.codepipeline.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning"]
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = "codestar-connections:UseConnection"
        Resource = aws_codestarconnections_connection.github.arn
      },
      {
        Effect = "Allow"
        Action = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = [
          aws_codebuild_project.unittest.arn,
          aws_codebuild_project.buildimage.arn,
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision",
        ]
        Resource = "*" # CodeDeploy actions don't support resource-level scoping on these APIs
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.codedeploy.arn
      },
    ]
  })
}

# --- Pipeline ---

resource "aws_codepipeline" "app" {
  name     = "appointments-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.pipeline_artifacts.bucket
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_repo_owner}/${var.github_repo_name}"
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "UnitTest"
    action {
      name            = "UnitTest"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration = {
        ProjectName = aws_codebuild_project.unittest.name
      }
    }
  }

  stage {
    name = "BuildImage"
    action {
      name             = "BuildImage"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.buildimage.name
      }
    }
  }

  # No separate "DeployPods" CodeBuild stage — CodePipeline's native
  # CodeDeploy action replaces it. It pulls appspec.yml + scripts/ +
  # image_tag.txt straight out of the BuildImage stage's output
  # artifact and drives the existing blue/green deployment group
  # (codedeploy.tf) directly; no `aws deploy create-deployment` CLI
  # call to maintain in a buildspec.
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["build_output"]
      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.app.deployment_group_name
      }
    }
  }
}
