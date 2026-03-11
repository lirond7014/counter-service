# ========================================
# MAIN TERRAFORM CONFIGURATION
# Uses official terraform-aws-modules for best practices
# ========================================

# ====== VPC MODULE ======
# Creates VPC, subnets, NAT Gateway, Internet Gateway, route tables
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # Spread across all AZs in the region for high availability
  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  # NAT Gateway for private subnet outbound internet access
  enable_nat_gateway = var.vpc_enable_nat_gateway
  single_nat_gateway = var.vpc_single_nat_gateway  # Set to false for HA (multi-NAT)

  # DNS configuration for EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Kubernetes subnet tags (required for AWS Load Balancer Controller)
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    # Tag for Karpenter (advanced auto-scaling, optional)
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = var.common_tags
}

# ====== EKS CLUSTER MODULE ======
# Creates Kubernetes control plane
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # API endpoint access (private for security + public for kubectl)
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access

  # Encryption for Kubernetes secrets at rest
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # VPC and subnet configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Kubernetes add-ons (CoreDNS, kube-proxy, VPC-CNI)
  # Always pull latest patch version for security updates
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # Managed node groups (Kubernetes worker nodes)
  eks_managed_node_groups = {
    general = {
      name            = "${var.cluster_name}-general"
      use_name_prefix = true

      # Auto-scaling configuration
      min_size     = var.min_node_count
      max_size     = var.max_node_count
      desired_size = var.desired_node_count

      # Instance configuration
      instance_types = [var.node_instance_type]
      capacity_type  = var.node_capacity_type  # ON_DEMAND (stable) or SPOT (cheap)

      # Labels for pod scheduling
      labels = local.node_labels

      # Root volume configuration
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            delete_on_termination = true
            encrypted             = true
          }
        }
      }

      tags = var.common_tags
    }
  }

  tags = var.common_tags
}

# ====== RDS POSTGRESQL DATABASE ======
# Multi-AZ encrypted database for counter persistence
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.cluster_name}-db"

  # Database engine
  engine               = "postgres"
  engine_version       = "15.4"
  family               = "postgres15"
  major_engine_version = "15"

  # Instance size
  instance_class = var.db_instance_class

  # Storage configuration
  allocated_storage     = var.db_allocated_storage
  storage_encrypted     = var.db_storage_encrypted
  storage_type          = "gp3"
  iops                  = 3000

  # Database credentials
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # High Availability
  multi_az               = var.db_multi_az
  publicly_accessible    = false  # CRITICAL: Never expose RDS to internet
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = module.vpc.database_subnet_group_name

  # Backups and maintenance
  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"
  skip_final_snapshot     = true

  # Enhanced monitoring (optional, adds cost)
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = var.common_tags
}

# ====== ECR CONTAINER REGISTRY ======
# Private Docker image repository
resource "aws_ecr_repository" "counter_service" {
  name                 = var.container_registry_name
  image_tag_mutability = "MUTABLE"  # Allow overwriting image tags (e.g., latest)

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

# ====== SECURITY GROUP FOR RDS ======
# Restrict inbound traffic to RDS from EKS nodes only
resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Security group for RDS PostgreSQL database"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from EKS worker nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
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

# ====== KMS KEY FOR EKS ENCRYPTION ======
# Encrypt Kubernetes secrets at rest
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster secret encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.common_tags
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}