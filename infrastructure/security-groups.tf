# Look up the existing cluster security group by name (no hard-coded sg-... IDs)
data "aws_security_group" "cluster_shared" {
  filter {
    name   = "group-name"
    values = ["liron-cluster-counter-service"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.platform.id]
  }
}