# ========================================
# OUTPUTS - Information needed after infrastructure is created
# Use these to configure Kubernetes and connect to databases
# ========================================

# ====== EKS CLUSTER OUTPUTS ======
output "eks_cluster_id" {
  description = "EKS cluster ID (for aws eks commands)"
  value       = module.eks.cluster_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API server endpoint (HTTPS)"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "Kubernetes version running in cluster"
  value       = module.eks.cluster_version
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "eks_cluster_security_group_id" {
  description = "Security group ID of EKS control plane"
  value       = module.eks.cluster_security_group_id
}

output "eks_node_security_group_id" {
  description = "Security group ID of EKS worker nodes"
  value       = module.eks.node_security_group_id
}

# ====== VPC OUTPUTS ======
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "vpc_private_subnets" {
  description = "List of private subnet IDs (where pods run)"
  value       = module.vpc.private_subnets
}

output "vpc_public_subnets" {
  description = "List of public subnet IDs (where load balancers attach)"
  value       = module.vpc.public_subnets
}

output "vpc_availability_zones" {
  description = "Availability zones used"
  value       = local.azs
}

# ====== RDS OUTPUTS ======
output "rds_endpoint" {
  description = "RDS instance endpoint (hostname:port)"
  value       = module.rds.db_instance_endpoint
  sensitive   = true  # Don't print in console
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.db_instance_name
}

output "rds_port" {
  description = "RDS database port"
  value       = module.rds.db_instance_port
}


output "rds_arn" {
  description = "RDS instance ARN"
  value       = module.rds.db_instance_arn
}

# ====== ECR OUTPUTS ======
output "ecr_repository_url" {
  description = "ECR repository URL (push Docker images here)"
  value       = aws_ecr_repository.counter_service.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.counter_service.arn
}

output "ecr_registry_id" {
  description = "ECR registry ID (AWS account ID)"
  value       = aws_ecr_repository.counter_service.registry_id
}

# ====== HELPER COMMANDS ======
output "configure_kubectl_command" {
  description = "Command to configure kubectl to connect to cluster"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${module.eks.cluster_name}"
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

# ====== CONNECTION STRINGS ======
output "rds_connection_string" {
  description = "PostgreSQL connection string for manual access"
  value       = "postgresql://${var.db_username}:PASSWORD@${module.rds.db_instance_address}:5432/${var.db_name}"
  sensitive   = true
}

output "rds_host" {
  description = "RDS hostname (use in Kubernetes ConfigMap)"
  value       = module.rds.db_instance_address
}