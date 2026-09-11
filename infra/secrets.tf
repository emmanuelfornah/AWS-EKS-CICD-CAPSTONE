# Closes the gap the project's own TECHNICAL_RUNBOOK.md already flags:
# "credentials set in deployment manifest" as plaintext env vars. The DB
# password problem is solved by IAM auth (rds.tf/iam.tf) instead — this
# secret covers what's left: Django's SECRET_KEY and any other app-level
# secret that isn't a DB credential. The container/appspec should fetch
# this at container-start time (`aws secretsmanager get-secret-value`,
# permitted by the app_secrets IAM policy) rather than have it baked
# into the launch template, an env var block, or a manifest file that
# ends up in CloudTrail/console history.

resource "random_password" "django_secret_key" {
  length  = 50
  special = true
}

resource "aws_secretsmanager_secret" "app_config" {
  name                    = "appointments/app-config"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id
  secret_string = jsonencode({
    DJANGO_SECRET_KEY = random_password.django_secret_key.result
  })

  lifecycle {
    ignore_changes = [secret_string] # rotate out-of-band, don't fight manual rotations with `terraform apply`
  }
}
