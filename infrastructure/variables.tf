# ====== AWS REGION ======
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}

# ====== ENVIRONMENT ======
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# ====== CLUSTER CONFIGURATION ======
variable "cluster_name" {
  description = "EKS cluster name - must be unique in AWS account"
  type        = string
  default     = "liron-counter"
}

variable "cluster_version" {
  description = "Kubernetes version (must be supported by EKS)"
  type        = string
  default     = "1.28"
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

# ====== VPC CONFIGURATION ======
variable "vpc_cidr" {
  description = "CIDR block for VPC (must not overlap with other VPCs you connect to)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets to reach internet"
  type        = bool
  default     = true
}

variable "vpc_single_nat_gateway" {
  description = "Use single NAT Gateway (set to false for multi-AZ HA)"
  type        = bool
  default     = false
}

# ====== NODE GROUP CONFIGURATION ======
variable "node_instance_type" {
  description = "EC2 instance type for worker nodes (t3.medium is cost-effective for labs)"
  type        = string
  default     = "t3.medium"
}

variable "desired_node_count" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
  
  validation {
    condition     = var.desired_node_count >= 2
    error_message = "Desired node count must be at least 2 for HA."
  }
}

variable "min_node_count" {
  description = "Minimum number of worker nodes (for auto-scaling)"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "Maximum number of worker nodes (for auto-scaling, HPA)"
  type        = number
  default     = 5
}

variable "node_capacity_type" {
  description = "Capacity type: ON_DEMAND (stable) or SPOT (cost-saving, interruptible)"
  type        = string
  default     = "ON_DEMAND"
  
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "Capacity type must be ON_DEMAND or SPOT."
  }
}

# ====== RDS DATABASE CONFIGURATION ======
variable "db_name" {
  description = "RDS database name (PostgreSQL database to create)"
  type        = string
  default     = "counterdb"
}

variable "db_instance_class" {
  description = "RDS instance class (db.t3.micro is free tier, db.t3.small for prod)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "Allocated storage must be at least 20 GB."
  }
}

variable "db_username" {
  description = "RDS master username (DO NOT use 'admin' or 'root')"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_username) >= 1
    error_message = "Database username cannot be empty."
  }
}

variable "db_password" {
  description = "RDS master password (min 8 chars, must have uppercase, lowercase, number, special char)"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters."
  }
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.db_backup_retention_period >= 1 && var.db_backup_retention_period <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

variable "db_storage_encrypted" {
  description = "Enable encryption at rest for RDS (REQUIRED for production)"
  type        = bool
  default     = true
}

variable "db_backup_retention" {
  description = "Number of days to retain backups (alias for db_backup_retention_period)"
  type        = number
  default     = 7
  
  validation {
    condition     = var.db_backup_retention >= 1 && var.db_backup_retention <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

# ====== ECR CONFIGURATION ======
variable "container_registry_name" {
  description = "ECR repository name for Docker images"
  type        = string
  default     = "liron-counter"
}

variable "ecr_scan_on_push" {
  description = "Enable image scanning on push (detects vulnerabilities)"
  type        = bool
  default     = true
}

variable "ecr_image_retention" {
  description = "Number of images to retain in ECR (older images auto-deleted)"
  type        = number
  default     = 10
}

variable "ecr_image_retention_count" {
  description = "Number of ECR images to retain before auto-deletion"
  type        = number
  default     = 10

  validation {
    condition     = var.ecr_image_retention_count >= 1
    error_message = "Must retain at least 1 image."
  }
}

# ====== COMMON TAGS ======
variable "common_tags" {
  description = "Common tags applied to all resources for cost tracking and organization"
  type        = map(string)
  default = {
    Project     = "counter-service"
    Environment = "prod"
    Team        = "platform"
    CostCenter  = "engineering"
  }
}