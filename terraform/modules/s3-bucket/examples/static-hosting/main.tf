# Static Website Hosting Example
# S3 bucket configured for static website hosting with CORS

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
resource "aws_kms_key" "website" {
  description             = "KMS key for website bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "website-bucket-key"
    Environment = var.environment
    Service     = "static-website"
    Team        = "frontend-team"
    Owner       = "frontend@example.com"
    CostCenter  = "engineering"
    Project     = "infrastructure"
    ManagedBy   = "Terraform"
  }
}

# S3 Bucket Module for Static Website
module "website_bucket" {
  source = "../../"

  bucket_name        = "${var.environment}-static-website-bucket"
  versioning_enabled = true

  # Required tags
  environment = var.environment
  service     = "static-website"
  team        = "frontend-team"
  owner       = "frontend@example.com"
  cost_center = "engineering"
  project     = "infrastructure"

  # Encryption with KMS
  kms_key_id = aws_kms_key.website.arn

  # Enable static website hosting
  enable_static_website  = true
  website_index_document = "index.html"
  website_error_document = "error.html"

  # Public access for website (adjust as needed)
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  # CORS configuration for API calls from website
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["https://example.com", "https://www.example.com"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]

  # Lifecycle policy
  lifecycle_rules = [
    {
      id      = "cleanup-old-versions"
      enabled = true
      prefix  = ""

      noncurrent_expiration_days   = 30 # Delete old versions after 30 days
      abort_incomplete_upload_days = 1  # Clean up incomplete uploads quickly
    }
  ]

  additional_tags = {
    Purpose     = "Static website hosting"
    ContentType = "Web"
  }
}
