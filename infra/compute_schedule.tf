# Seasonal demand: booking volume drops heading into the cold season
# (end of summer onward) and picks back up in late spring. This was
# meant to trim burst *capacity*, not the HA floor — min_size staying 2
# year-round (one instance per AZ), only max_size/desired_capacity
# moving seasonally.
#
# Removed (not just disabled) rather than left in place: the resources
# targeted "appointments-asg" by name, but that ASG no longer exists at
# all post-deployment — CodeDeploy's ASG-copy blue/green replaces it
# with a new, differently-named ASG every deployment (see the long
# comment in compute.tf). Tried leaving them declared with a hardcoded
# name and letting `apply` fail loudly as an honest "known broken"
# marker — worse than expected: it's a hard error on *every* apply
# ("AutoScalingGroup name not found - null"), not the silent no-op
# originally assumed, which would have broken every future apply for
# this whole stack, not just this one feature.
#
# Needs a real redesign before this comes back — e.g. a small Lambda,
# triggered on the same EventBridge schedule, that looks up whatever
# ASG CodeDeploy currently has the deployment group pointed at and
# resizes that one, since Terraform can no longer name it statically.
