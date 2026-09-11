resource "aws_cloudwatch_log_group" "app" {
  name              = "/appointments/app"
  retention_in_days = 30
}

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_launch_template" "app" {
  name_prefix   = "appointments-"
  image_id      = data.aws_ssm_parameter.al2023_arm64.value
  instance_type = var.instance_type

  # No key_name — no SSH keypair exists for these instances at all.
  # Access is exclusively via SSM Session Manager (iam.tf), which is
  # logged to CloudTrail and doesn't require an open inbound port.

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only — closes the SSRF-to-credential-theft path IMDSv1 allows
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  monitoring {
    enabled = true # detailed CloudWatch metrics, matters for ASG scaling responsiveness
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data.sh.tpl", {
    aws_region        = var.aws_region
    log_group         = aws_cloudwatch_log_group.app.name
    secret_arn        = aws_secretsmanager_secret.app_config.arn
    database_host     = aws_db_instance.main.address
    db_username       = var.db_username
    db_name           = var.db_name
    app_port          = var.app_port
    health_check_path = var.health_check_path
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "appointments-app" }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "appointments-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_min_size
  vpc_zone_identifier = aws_subnet.private_app[*].id

  # Spread across AZs, not just across subnets within one -- this is
  # what actually gives HA against an AZ outage.
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app.arn] # CodeDeploy manages ASG membership here during blue/green deploys

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
    }
  }

  tag {
    key                 = "Name"
    value               = "appointments-app"
    propagate_at_launch = true
  }
}
