# Basic CloudFront Distribution Example
# This example creates a simple CloudFront distribution with default settings

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# S3 Bucket for origin
resource "aws_s3_bucket" "origin" {
  bucket = "my-cloudfront-origin-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "origin" {
  bucket = aws_s3_bucket.origin.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "OAI for ${aws_s3_bucket.origin.id}"
}

# S3 Bucket Policy for CloudFront
resource "aws_s3_bucket_policy" "origin" {
  bucket = aws_s3_bucket.origin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.this.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.origin.arn}/*"
      }
    ]
  })
}

# CloudFront Distribution Module
module "cloudfront" {
  source = "../../"

  comment = "basic-example-cdn"
  enabled = true

  # S3 Origin
  origins = {
    s3 = {
      domain_name = aws_s3_bucket.origin.bucket_regional_domain_name
      origin_id   = "S3-${aws_s3_bucket.origin.id}"

      s3_origin_config = {
        origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
      }
    }
  }

  # Default Cache Behavior
  default_cache_behavior = {
    target_origin_id       = "S3-${aws_s3_bucket.origin.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values = {
      query_string = false
      headers      = []
      cookies = {
        forward = "none"
      }
    }
  }

  # Common tags
  common_tags = {
    Environment = "dev"
    Service     = "example"
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
  }
}

# Data sources
data "aws_caller_identity" "current" {}

# Outputs
output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.distribution_domain_name
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = module.cloudfront.distribution_arn
}
