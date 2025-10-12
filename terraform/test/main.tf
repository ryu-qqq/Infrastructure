# Test Terraform configuration for Atlantis integration testing
# This creates a simple S3 bucket to verify Atlantis workflow

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "s3" {
    bucket         = "terraform-state-ryu-qqq"
    key            = "infrastructure/test/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

# Random suffix for unique bucket name
resource "random_id" "suffix" {
  byte_length = 4
}

# Test S3 bucket
resource "aws_s3_bucket" "atlantis-test" {
  bucket = "atlantis-test-${random_id.suffix.hex}"

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-test-${random_id.suffix.hex}"
      Component   = "atlantis-test"
      Description = "Test bucket for Atlantis webhook integration testing"
    }
  )
}

# Enable versioning
resource "aws_s3_bucket_versioning" "atlantis-test" {
  bucket = aws_s3_bucket.atlantis-test.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "atlantis-test" {
  bucket = aws_s3_bucket.atlantis-test.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
