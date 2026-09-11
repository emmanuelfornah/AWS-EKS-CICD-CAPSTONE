resource "aws_codedeploy_app" "app" {
  name             = "appointments"
  compute_platform = "Server" # EC2/On-Premises
}

resource "aws_codedeploy_deployment_group" "app" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "appointments-blue-green"
  service_role_arn      = aws_iam_role.codedeploy.arn

  autoscaling_groups = [aws_autoscaling_group.app.name]

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  # Auto-rollback on a failed deployment or a triggered CloudWatch
  # alarm — a bad release never gets to stay live because nobody
  # noticed the health check failing.
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled = true
    alarms  = [aws_cloudwatch_metric_alarm.unhealthy_hosts.alarm_name]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 30 # bake window — instant rollback is just not-yet-terminated blue
    }
  }

  # ASG-based blue/green (autoscaling_groups above) needs a single
  # target_group_info, not target_group_pair_info — the AWS API rejects
  # that combination (target_group_pair_info's two-target-group
  # traffic-shift model is for deployments without an ASG, e.g.
  # ECS/Lambda or tag-based EC2). In this model the listener never
  # changes which target group it forwards to; CodeDeploy provisions a
  # temporary replacement ASG per deployment and registers its
  # instances to this same target group, then terminates the old ASG's
  # instances after the bake window.
  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.app.name
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "appointments-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
  alarm_description = "Trips a CodeDeploy rollback if the target group has any unhealthy host during a deploy"
}
