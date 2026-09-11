# App connects via IAM auth (rds-db:connect, see iam.tf) — no DB
# password ever touches app code, env vars, or the appspec. RDS still
# needs a master credential for administration; that's generated and
# rotated by RDS itself into Secrets Manager (manage_master_user_password),
# so nobody — including this Terraform run — ever sees it in plaintext.

resource "aws_kms_key" "rds" {
  description             = "RDS storage encryption - appointments"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_db_subnet_group" "main" {
  name       = "appointments-db-subnet-group"
  subnet_ids = aws_subnet.private_data[*].id
}

resource "aws_db_instance" "main" {
  identifier        = "scheduler-db" # matches the name already in use
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.db_instance_class
  allocated_storage = 20 # GB — RDS free-tier ceiling, plenty at this app's scale
  storage_type      = "gp3"

  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true # RDS-managed secret, auto-rotated, never exposed to us

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  iam_database_authentication_enabled = true

  multi_az                  = var.db_multi_az
  backup_retention_period   = 7
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "scheduler-db-final"

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
}
