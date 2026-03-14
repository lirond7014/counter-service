resource "aws_security_group_rule" "node_sg_to_sts" {
  type              = "ingress"
  description       = "Allow VPC to access STS endpoint"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.platform.cidr_block]
  security_group_id = data.aws_security_group.node_existing.id
}