variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name (must match console cluster)"
  type        = string
  default     = "liron-counter"
}

# ====== ADDED TO MATCH terraform.tfvars ======
variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.28"
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_enable_nat_gateway" {
  description = "Enable NAT Gateway in VPC"
  type        = bool
  default     = true
}

variable "vpc_single_nat_gateway" {
  description = "Use a single NAT Gateway (for cost savings)"
  type        = bool
  default     = false
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_node_count" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 5
}

variable "node_capacity_type" {
  description = "Capacity type for EKS nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID (existing, created via console)"
  type        = string
  default     = "vpc-0e44d65c95048f4ca"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (existing, created via console)"
  type        = list(string)
  default = [
    "subnet-059ec78ac2906d2a1",
    "subnet-0d548885ff1b0b130",
    "subnet-099c75d5b0d4db750",
    "subnet-0b637bbceaf8649b1"
  ]
}

variable "node_iam_role_name" {
  description = "Node IAM role name (created via console)"
  type        = string
  default     = "liron-counter-node"
}

variable "container_registry_name" {
  description = "ECR repository name"
  type        = string
  default     = "liron-counter"
}

variable "ecr_scan_on_push" {
  description = "Scan images for vulnerabilities on push"
  type        = bool
  default     = true
}

variable "ecr_image_retention_count" {
  description = "Number of images to retain in ECR"
  type        = number
  default     = 10
}

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_storage_encrypted" {
  description = "Encrypt RDS storage"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "counterdb"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"  # Change this to a secure password!
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Number of days to retain RDS backups"
  type        = number
  default     = 1
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "counter-service"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}