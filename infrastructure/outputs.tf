output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = data.aws_eks_cluster.platform.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = data.aws_eks_cluster.platform.endpoint
}

output "vpc_id" {
  description = "VPC ID"
  value       = data.aws_vpc.platform.id
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.counter_service.repository_url
}

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.db_instance_name
}