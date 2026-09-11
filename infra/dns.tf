# The root domain and its Route 53 hosted zone are pre-existing —
# registered separately, not managed by this Terraform. Referenced via
# data source so this record can still be declared here rather than as
# a one-off CLI call, keeping it in the same reproducible state as
# everything else in this stack.

data "aws_route53_zone" "root" {
  name = var.root_domain
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
