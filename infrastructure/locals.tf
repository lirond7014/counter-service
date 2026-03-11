# Local values - computed once, reused everywhere
# This reduces duplication and makes changes easier

locals {
  # Get all availability zones in the region
  azs = data.aws_availability_zones.available.names
  
  # Compute private subnet CIDR blocks dynamically
  # Example: VPC 10.0.0.0/16 → private subnets: 10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24
  private_subnets = [
    for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)
  ]
  
  # Compute public subnet CIDR blocks dynamically
  # Uses indices 10-12 to avoid overlap with private subnets
  public_subnets = [
    for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 10)
  ]
  
  # Kubernetes node labels
  node_labels = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Data source: Fetch available AZs in the region
# This ensures we always deploy across all AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source: Get current AWS account ID (useful for ARNs)
data "aws_caller_identity" "current" {}

# Data source: Get current region
data "aws_region" "current" {}