# Least-privilege IAM: every policy below is scoped to a specific
# resource ARN, not "*". This replaces the appointments-sa IRSA role
# from the EKS design — same permission set, different trust model.

data "aws_caller_identity" "current" {}

# --- EC2 instance role (what the app itself runs as) ---

resource "aws_iam_role" "app_instance" {
  name = "appointments-app-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "appointments-app-instance-profile"
  role = aws_iam_role.app_instance.name
}

# SSM Session Manager instead of SSH keypairs/open port 22 — access is
# via `aws ssm start-session`, logged to CloudTrail, no bastion host,
# no key material to leak.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "codedeploy_agent" {
  role       = aws_iam_role.app_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

resource "aws_iam_role_policy" "app_ecr_pull" {
  name = "ecr-pull-scoped"
  role = aws_iam_role.app_instance.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*" # this specific action has no resource-level permission support
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
        ]
        Resource = aws_ecr_repository.app.arn
      },
    ]
  })
}

resource "aws_iam_role_policy" "app_dynamodb" {
  name = "dynamodb-scoped"
  role = aws_iam_role.app_instance.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
      ]
      Resource = aws_dynamodb_table.announcements.arn
    }]
  })
}

resource "aws_iam_role_policy" "app_rds_iam_auth" {
  name = "rds-iam-auth-scoped"
  role = aws_iam_role.app_instance.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "rds-db:connect"
      Resource = "arn:aws:rds-db:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.main.resource_id}/${var.db_username}"
    }]
  })
}

resource "aws_iam_role_policy" "app_secrets" {
  name = "secrets-read-scoped"
  role = aws_iam_role.app_instance.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.app_config.arn
    }]
  })
}

resource "aws_iam_role_policy" "app_cloudwatch_logs" {
  name = "cloudwatch-logs-scoped"
  role = aws_iam_role.app_instance.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      # No logs:CreateLogGroup — compute.tf already creates this log group,
      # and start_container.sh runs the awslogs driver with
      # awslogs-create-group=false, so the instance never needs to create one.
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.app.arn}:*"
    }]
  })
}

# --- CodeDeploy service role (what CodeDeploy assumes to drive the ASG/ALB) ---

resource "aws_iam_role" "codedeploy" {
  name = "appointments-codedeploy-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_service" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}
