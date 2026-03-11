# Counter Service Infrastructure (Terraform)

This directory contains production-grade Infrastructure as Code (IaC) using Terraform to provision the entire AWS infrastructure for the counter-service Kubernetes deployment.

## What Gets Created

| Resource | Purpose | Cost (Monthly) |
|----------|---------|---|
| **EKS Cluster** | Kubernetes control plane | $73 |
| **EC2 Nodes** | 2x t3.medium worker nodes | ~$60 |
| **RDS PostgreSQL** | Multi-AZ encrypted database | $150+ |
| **NAT Gateway** | Outbound internet for private subnets | $30-45 |
| **ECR Repository** | Private Docker registry | ~$1 |
| **KMS Encryption** | Secret encryption at rest | ~$1 |
| **Total** | **Monthly infrastructure cost** | **~$315-320** |

## Architecture
