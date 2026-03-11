# ========================================
# MAIN TERRAFORM CONFIGURATION
# References existing EKS cluster and creates supporting infrastructure
# ========================================

# ====== DATA SOURCES: Reference Existing Resources ======

# Reference the existing EKS cluster (created via AWS Console)
data "aws_eks_cluster" "platform" {
  name = var.cluster_name
}

# Reference the existing VPC
data "aws_vpc" "platform" {
  id = var.vpc_id
}

# Reference the existing subnets
data "aws_subnets" "private" {
  filter {
    name   = "subnet-id"
    values = var.private_subnet_ids
  }
}

# Reference the existing Node IAM role
data "aws_iam_role" "node_group" {
  name = var.node_iam_role_name
}

# ====== ECR CONTAINER REGISTRY ======
# Private Docker image repository
resource "aws_ecr_repository" "counter_service" {
  name                 = var.container_registry_name
  image_tag_mutability = "MUTABLE"

  # Image scanning for vulnerabilities
  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }

  # Encryption
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.common_tags
}

# ECR lifecycle policy: Keep last N images, auto-delete old ones
resource "aws_ecr_lifecycle_policy" "counter_service" {
  repository = aws_ecr_repository.counter_service.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = var.ecr_image_retention_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ====== RDS POSTGRESQL DATABASE ======
# Encrypted database for counter persistence
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.cluster_name}-db"

  # Database engine
  engine               = "postgres"
  engine_version       = "16.10"
  family               = "postgres16"
  major_engine_version = "16"

  # Instance size
  instance_class = var.db_instance_class

  # Storage configuration
  allocated_storage     = var.db_allocated_storage
  storage_encrypted     = var.db_storage_encrypted
  storage_type          = "gp3"

  # Database credentials
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # High Availability
  multi_az               = var.db_multi_az
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.rds.name

  # Backups and maintenance
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"
  skip_final_snapshot     = true

  # Enhanced monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = var.common_tags
}

# Create RDS subnet group from existing subnets
resource "aws_db_subnet_group" "rds" {
  name       = "${var.cluster_name}-db-subnets"
  subnet_ids = data.aws_subnets.private.ids
  tags       = var.common_tags
}

# ====== SECURITY GROUP FOR RDS ======
# Restrict inbound traffic to RDS from EKS nodes only
resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Security group for RDS PostgreSQL database"
  vpc_id      = data.aws_vpc.platform.id

  ingress {
    description = "PostgreSQL from EKS worker nodes"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.platform.cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.common_tags
}