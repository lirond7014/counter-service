terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state stored in S3 with DynamoDB locking
  # IMPORTANT: You must manually create the S3 bucket and DynamoDB table first!
  # See README.md for setup instructions
  backend "s3" {
    bucket         = "liron-counter-service-terraform-state"  
    key            = "prod/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "liron-counter-service-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  # Auto-tag all resources
  default_tags {
    tags = {
      Project     = "counter-service"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}