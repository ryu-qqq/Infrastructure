# Logging Bucket Example
# S3 bucket optimized for storing application and access logs

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

# KMS key for log bucket encryption
resource "aws_kms_key" "logs" {
  description             = "KMS key for log bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "logs-bucket-key"
    Environment = var.environment
    Service     = "logging"
    Team        = "platform-team"
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
    Project     = "infrastructure"
    ManagedBy   = "Terraform"
  }
}

# S3 Bucket Module for Logs
module "logs_bucket" {
  source = "../../"

  bucket_name        = "${var.environment}-application-logs-bucket"
  versioning_enabled = false # Logs typically don't need versioning

  # Required tags
  environment = var.environment
  service     = "logging"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  project     = "infrastructure"

  # Encryption with KMS
  kms_key_id = aws_kms_key.logs.arn

  # Aggressive lifecycle policy for logs
  lifecycle_rules = [
    {
      id      = "archive-logs"
      enabled = true
      prefix  = ""

      transition_to_ia_days      = 7  # Move to IA after 7 days
      transition_to_glacier_days = 30 # Move to Glacier after 30 days
      expiration_days            = 90 # Delete after 90 days

      abort_incomplete_upload_days = 1 # Clean up incomplete uploads immediately
    },
    {
      id      = "delete-error-logs-quickly"
      enabled = true
      prefix  = "errors/"

      expiration_days = 30 # Delete error logs after 30 days
    }
  ]

  additional_tags = {
    Purpose  = "Application and access logs storage"
    DataType = "Logs"
  }
}
