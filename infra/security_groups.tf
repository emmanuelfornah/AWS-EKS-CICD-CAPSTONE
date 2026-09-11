# Three-tier SG chain: internet -> ALB -> app -> db. Nothing skips a
# tier, and nothing is open to 0.0.0.0/0 except the ALB's public
# listener. No SG anywhere allows inbound 22 — access is via SSM
# Session Manager (see compute.tf), not SSH.
#
# Rules are separate aws_vpc_security_group_*_rule resources rather than
# inline ingress/egress blocks: alb -> app and app -> alb reference each
# other, which is a real dependency cycle if expressed as inline blocks
# on the SG resources themselves. Standalone rule resources break that
# cycle (each rule depends on both SGs, but the two empty SG resources
# no longer depend on each other).

resource "aws_security_group" "alb" {
  name        = "appointments-alb-sg"
  description = "Public ALB - HTTPS only, redirects HTTP"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "app" {
  name        = "appointments-app-sg"
  description = "App instances - traffic from ALB only, no direct internet inbound"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "rds" {
  name        = "appointments-rds-sg"
  description = "RDS MySQL - reachable only from app instances"
  vpc_id      = aws_vpc.main.id
}

# --- ALB ---

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each          = toset(var.alb_ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from allowed CIDRs"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each          = toset(var.alb_ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  description       = "HTTP (redirected to HTTPS at the listener, not a bypass)"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To app instances only"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

# --- App ---

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from ALB"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_egress_all" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound for ECR pulls / package updates / RDS / DynamoDB"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- RDS ---

resource "aws_vpc_security_group_ingress_rule" "rds_from_app" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from app tier"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "rds_egress_all" {
  security_group_id = aws_security_group.rds.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
