# CloudFront Distribution with S3 Origin Example
# This example shows advanced CloudFront configuration with S3 static website

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

# S3 Bucket for static website
resource "aws_s3_bucket" "website" {
  bucket = "my-static-website-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket for logs
resource "aws_s3_bucket" "logs" {
  bucket = "my-cloudfront-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "OAI for ${aws_s3_bucket.website.id}"
}

# S3 Bucket Policy for CloudFront
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.this.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# CloudFront Distribution Module
module "cloudfront" {
  source = "../../"

  comment             = "s3-static-website-cdn"
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  # S3 Origin
  origins = {
    s3_website = {
      domain_name = aws_s3_bucket.website.bucket_regional_domain_name
      origin_id   = "S3-${aws_s3_bucket.website.id}"

      s3_origin_config = {
        origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
      }
    }
  }

  # Default Cache Behavior
  default_cache_behavior = {
    target_origin_id       = "S3-${aws_s3_bucket.website.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    default_ttl            = 3600
    max_ttl                = 86400
    min_ttl                = 0

    forwarded_values = {
      query_string = false
      headers      = []
      cookies = {
        forward = "none"
      }
    }
  }

  # Path-based cache behaviors for static assets
  ordered_cache_behaviors = [
    {
      path_pattern           = "/static/*"
      target_origin_id       = "S3-${aws_s3_bucket.website.id}"
      viewer_protocol_policy = "https-only"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      default_ttl            = 86400    # 1 day
      max_ttl                = 31536000 # 1 year
      min_ttl                = 0

      forwarded_values = {
        query_string = false
        headers      = []
        cookies = {
          forward = "none"
        }
      }
    },
    {
      path_pattern           = "/images/*"
      target_origin_id       = "S3-${aws_s3_bucket.website.id}"
      viewer_protocol_policy = "https-only"
      allowed_methods        = ["GET", "HEAD"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      default_ttl            = 86400
      max_ttl                = 31536000
      min_ttl                = 0

      forwarded_values = {
        query_string = false
        headers      = []
        cookies = {
          forward = "none"
        }
      }
    }
  ]

  # Custom error responses for SPA
  custom_error_responses = [
    {
      error_code         = 404
      response_code      = 200
      response_page_path = "/index.html"
    },
    {
      error_code         = 403
      response_code      = 200
      response_page_path = "/index.html"
    }
  ]

  # Logging
  logging_config = {
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    include_cookies = false
    prefix          = "cloudfront/"
  }

  # Geo restriction (example: block specific countries)
  geo_restriction = {
    restriction_type = "none"
    locations        = []
  }

  # Common tags
  common_tags = {
    Environment = "prod"
    Service     = "website"
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

output "s3_bucket_name" {
  description = "S3 bucket name for static website"
  value       = aws_s3_bucket.website.id
}

output "logs_bucket_name" {
  description = "S3 bucket name for CloudFront logs"
  value       = aws_s3_bucket.logs.id
}
