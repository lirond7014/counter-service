locals {
  # Environment and project naming
  cluster_name = var.cluster_name
  environment  = var.environment
  project_name = "counter-service"

  # Common tags for all resources
  common_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
    }
  )
}