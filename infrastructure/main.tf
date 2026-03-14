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

# Reference the existing Node IAM role
data "aws_iam_role" "node_group" {
  name = var.node_iam_role_name
}

# Get AWS account ID
data "aws_caller_identity" "current" {}

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
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_image_retention_count
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
  allocated_storage = var.db_allocated_storage
  storage_encrypted = var.db_storage_encrypted
  storage_type      = "gp3"

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

# Create RDS subnet group from discovered private subnets
resource "aws_db_subnet_group" "rds" {
  name       = "${var.cluster_name}-db-subnets"
  subnet_ids = local.private_subnet_ids
  tags       = var.common_tags
}

# ====== SECURITY GROUP FOR RDS ======
# Restrict inbound traffic to RDS from EKS nodes only
resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Security group for RDS PostgreSQL database"
  vpc_id      = data.aws_vpc.platform.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.common_tags
}

resource "aws_security_group_rule" "rds_postgres_from_nodes" {
  type                     = "ingress"
  description              = "PostgreSQL from EKS worker nodes"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = data.aws_security_group.node_existing.id
}



# ====== NODE SECURITY GROUP LOOKUP ======
# Reference the existing node security group
data "aws_security_group" "node_existing" {
  id = var.node_security_group_id
}

# ====== ADD MISSING ECR API ENDPOINT RULE ======
# Allow nodes to reach the cluster shared security group on 443 (used by your endpoints setup)
resource "aws_security_group_rule" "ecr_api_https_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.node_existing.id
  security_group_id        = data.aws_security_group.cluster_shared.id
  description              = "Allow nodes to pull from ECR API endpoint"
}

# ====== EBS CSI DRIVER ADDON ======
# Required for EBS volume provisioning with StorageClass

# Create IAM role for EBS CSI driver
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.platform.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.platform.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(data.aws_eks_cluster.platform.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# Attach the AWS managed policy for EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# Install EBS CSI driver addon
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = data.aws_eks_cluster.platform.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.56.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  tags = var.common_tags

  depends_on = [aws_iam_role_policy_attachment.ebs_csi_driver]
}

# ====== NODE ECR PULL POLICY (attached inline to node role) ======
resource "aws_iam_role_policy" "node_ecr_pull" {
  name = "${var.cluster_name}-node-ecr-pull"
  role = data.aws_iam_role.node_group.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/eks/*"
      }
    ]
  })
}

# ====== STS VPC ENDPOINT FOR EBS CSI DRIVER ======
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = data.aws_vpc.platform.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = local.private_subnet_ids
  security_group_ids = [data.aws_security_group.node_existing.id]

  tags = {
    Name = "${var.cluster_name}-sts-endpoint"
  }
}

# ====== EC2 VPC ENDPOINT FOR EBS CSI DRIVER ======
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = data.aws_vpc.platform.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = local.private_subnet_ids
  security_group_ids = [data.aws_security_group.node_existing.id]

  tags = {
    Name = "${var.cluster_name}-ec2-endpoint"
  }
}