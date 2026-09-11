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
#
# KNOWN GAP, not yet resolved: these target "appointments-asg" by name,
# but that ASG no longer exists post-deployment — CodeDeploy's ASG-copy
# blue/green replaces it with a new, differently-named ASG on every
# deployment (see the comment in compute.tf). A scheduled action against
# a nonexistent ASG name is a silent no-op, not an error — so this
# feature currently does not actually run against whatever ASG is live.
# Needs its own fix (e.g. a small Lambda that discovers the current
# CodeDeploy-created ASG name and resizes it on the same schedule)
# before this can be called working again, not just deployed.

resource "aws_autoscaling_schedule" "low_season" {
  scheduled_action_name  = "low-season-scale-down"
  autoscaling_group_name = "appointments-asg"
  recurrence             = "0 0 1 9 *" # Sept 1, every year
  min_size               = 2
  max_size               = 2
  desired_capacity       = 2
}

resource "aws_autoscaling_schedule" "high_season" {
  scheduled_action_name  = "high-season-scale-up"
  autoscaling_group_name = "appointments-asg"
  recurrence             = "0 0 1 6 *" # June 1, every year
  min_size               = 2
  max_size               = 4
  desired_capacity       = 2
}
