# CloudFront Distribution for CDN
# cdn.set-of.com - Multi-origin configuration

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}

# ACM Certificate (must be in us-east-1 for CloudFront)
data "aws_acm_certificate" "cdn" {
  provider    = aws.us_east_1
  domain      = "*.set-of.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

# Route53 Zone
data "aws_route53_zone" "main" {
  name = "set-of.com."
}

# ============================================================================
# CloudFront Origin Access Control (OAC)
# ============================================================================

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${local.name_prefix}-s3-oac"
  description                       = "OAC for S3 origins"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ============================================================================
# CloudFront Distribution
# ============================================================================

resource "aws_cloudfront_distribution" "cdn" {
  comment             = "CDN for set-of.com - Multi S3 Origins"
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = var.price_class
  default_root_object = "index.html"
  aliases             = [var.domain_name]

  # ----------------------------------------------------------------------------
  # Origin: connectly-prod (Default - Legacy)
  # ----------------------------------------------------------------------------
  origin {
    domain_name              = local.origins.connectly_prod.domain_name
    origin_id                = local.origins.connectly_prod.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # ----------------------------------------------------------------------------
  # Origin: prod-connectly (OTEL Config)
  # ----------------------------------------------------------------------------
  origin {
    domain_name              = local.origins.prod_connectly.domain_name
    origin_id                = local.origins.prod_connectly.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # ----------------------------------------------------------------------------
  # Origin: fileflow-uploads-prod (File Uploads)
  # ----------------------------------------------------------------------------
  origin {
    domain_name              = local.origins.fileflow_uploads.domain_name
    origin_id                = local.origins.fileflow_uploads.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # ----------------------------------------------------------------------------
  # Default Cache Behavior (connectly-prod - Legacy)
  # ----------------------------------------------------------------------------
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.connectly_prod.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /otel-config/* -> prod-connectly
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/otel-config/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.prod_connectly.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 300   # 5 minutes (config files need faster updates)
    max_ttl     = 3600  # 1 hour
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /uploads/* -> fileflow-uploads-prod
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/uploads/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.fileflow_uploads.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # SSL/TLS Configuration
  # ----------------------------------------------------------------------------
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.cdn.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # ----------------------------------------------------------------------------
  # WAF (existing WAF ACL)
  # ----------------------------------------------------------------------------
  web_acl_id = "arn:aws:wafv2:us-east-1:646886795421:global/webacl/CreatedByCloudFront-a3ce33d0/bf764595-cb95-4137-b247-5544fee11c1f"

  # ----------------------------------------------------------------------------
  # Restrictions
  # ----------------------------------------------------------------------------
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # ----------------------------------------------------------------------------
  # Tags
  # ----------------------------------------------------------------------------
  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-distribution"
      Component = "cloudfront"
    }
  )
}

# ============================================================================
# Route53 Record for cdn.set-of.com
# ============================================================================

resource "aws_route53_record" "cdn" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

# ============================================================================
# S3 Bucket Policies for CloudFront Access
# ============================================================================

# Policy for connectly-prod bucket
resource "aws_s3_bucket_policy" "connectly_prod" {
  bucket = "connectly-prod"
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "PolicyForCloudFrontPrivateContent"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::connectly-prod/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

# Policy for prod-connectly bucket (otel-config only)
resource "aws_s3_bucket_policy" "prod_connectly" {
  bucket = "prod-connectly"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::prod-connectly",
          "arn:aws:s3:::prod-connectly/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::prod-connectly/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid       = "AllowCloudFrontOtelConfig"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::prod-connectly/otel-config/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

# Policy for fileflow-uploads-prod bucket
resource "aws_s3_bucket_policy" "fileflow_uploads" {
  bucket = "fileflow-uploads-prod"
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "PolicyForCloudFrontFileflowUploads"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::fileflow-uploads-prod/uploads/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}
