# Discover VPC subnets by Name tag (private vs public)
# This avoids hard-coded subnet IDs drifting and accidentally using public subnets for RDS/endpoints.

data "aws_subnets" "private_by_name" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.platform.id]
  }

  tags = {
    # matches: liron-counter-subnet-private1-eu-west-2a, private2, etc.
    Name = "*private*"
  }
}

data "aws_subnets" "public_by_name" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.platform.id]
  }

  tags = {
    Name = "*public*"
  }
}

locals {
  private_subnet_ids = data.aws_subnets.private_by_name.ids
  public_subnet_ids  = data.aws_subnets.public_by_name.ids
}