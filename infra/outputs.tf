output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "db_resource_id" {
  description = "Needed to construct the rds-db:connect ARN for IAM auth clients"
  value       = aws_db_instance.main.resource_id
}

output "app_secret_arn" {
  value = aws_secretsmanager_secret.app_config.arn
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.app.name
}

output "codepipeline_name" {
  value = aws_codepipeline.app.name
}

output "codestar_connection_arn" {
  description = "Comes up PENDING — finish the GitHub App handshake in the CodePipeline console (Settings > Connections) before the pipeline can run"
  value       = aws_codestarconnections_connection.github.arn
}
