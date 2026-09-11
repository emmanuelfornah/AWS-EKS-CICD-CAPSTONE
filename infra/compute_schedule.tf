# Seasonal demand: booking volume drops heading into the cold season
# (end of summer onward) and picks back up in late spring. This trims
# burst *capacity*, not the HA floor — min_size stays 2 year-round (one
# instance per AZ) in both schedules, so the multi-AZ story never gets
# weaker just because it's a slow month. Only max_size (headroom for a
# traffic spike) and desired_capacity move.
#
# Month boundaries are illustrative/tunable, not derived from real
# booking data — adjust once there's an actual season-over-season
# traffic pattern to look at.

resource "aws_autoscaling_schedule" "low_season" {
  scheduled_action_name  = "low-season-scale-down"
  autoscaling_group_name = aws_autoscaling_group.app.name
  recurrence             = "0 0 1 9 *" # Sept 1, every year
  min_size               = 2
  max_size               = 2
  desired_capacity       = 2
}

resource "aws_autoscaling_schedule" "high_season" {
  scheduled_action_name  = "high-season-scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  recurrence             = "0 0 1 6 *" # June 1, every year
  min_size               = 2
  max_size               = 4
  desired_capacity       = 2
}
