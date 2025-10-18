# Basic S3 Bucket Example
# Simple data storage bucket with versioning and lifecycle policies

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# KMS key for bucket encryption
resource "aws_kms_key" "bucket" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "s3-bucket-key"
    Environment = var.environment
    Service     = "data-storage"
    Team        = "platform-team"
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
    Project     = "infrastructure"
    ManagedBy   = "Terraform"
  }
}

# S3 Bucket Module
module "data_bucket" {
  source = "../../"

  bucket_name        = "${var.environment}-data-storage-bucket"
  versioning_enabled = true

  # Required tags
  environment = var.environment
  service     = "data-storage"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  project     = "infrastructure"

  # Encryption with KMS
  kms_key_id = aws_kms_key.bucket.arn

  # Lifecycle policy for cost optimization
  lifecycle_rules = [
    {
      id      = "archive-old-data"
      enabled = true
      prefix  = ""

      transition_to_ia_days      = 30  # Move to IA after 30 days
      transition_to_glacier_days = 90  # Move to Glacier after 90 days
      expiration_days            = 365 # Delete after 1 year

      noncurrent_expiration_days   = 30 # Delete old versions after 30 days
      abort_incomplete_upload_days = 7  # Clean up incomplete uploads
    }
  ]

  additional_tags = {
    Purpose = "General data storage"
  }
}
