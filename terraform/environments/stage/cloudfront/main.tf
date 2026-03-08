# Stage CloudFront Distribution
# stage-cdn.set-of.com - Multi-origin with Signed URL support

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
# Signed URL Key Pair (RSA)
# ============================================================================

# RSA key pair for CloudFront Signed URL
resource "tls_private_key" "cloudfront_signing" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Store private key in Secrets Manager (backend uses this to generate Signed URLs)
resource "aws_secretsmanager_secret" "cloudfront_private_key" {
  name        = "${local.name_prefix}-signing-private-key"
  description = "CloudFront Signed URL private key for /internal/* path"

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-signing-private-key"
      Component = "cloudfront-signing"
    }
  )
}

resource "aws_secretsmanager_secret_version" "cloudfront_private_key" {
  secret_id     = aws_secretsmanager_secret.cloudfront_private_key.id
  secret_string = tls_private_key.cloudfront_signing.private_key_pem
}

# CloudFront Public Key
resource "aws_cloudfront_public_key" "internal" {
  name        = "${local.name_prefix}-internal-public-key"
  comment     = "Public key for /internal/* Signed URL verification"
  encoded_key = tls_private_key.cloudfront_signing.public_key_pem
}

# CloudFront Key Group
resource "aws_cloudfront_key_group" "internal" {
  name    = "${local.name_prefix}-internal-key-group"
  comment = "Key group for /internal/* Signed URL access"
  items   = [aws_cloudfront_public_key.internal.id]
}

# ============================================================================
# CloudFront Distribution
# ============================================================================

resource "aws_cloudfront_distribution" "cdn" {
  comment             = "Stage CDN for set-of.com - stage-cdn.set-of.com"
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = var.price_class
  default_root_object = "index.html"
  aliases             = [var.domain_name]

  # WAF not applied for stage environment

  # ----------------------------------------------------------------------------
  # Origin: stage-connectly (Default + OTEL Config)
  # ----------------------------------------------------------------------------
  origin {
    domain_name              = local.origins.stage_connectly.domain_name
    origin_id                = local.origins.stage_connectly.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # ----------------------------------------------------------------------------
  # Origin: fileflow-uploads-stage (Public + Internal files)
  # ----------------------------------------------------------------------------
  origin {
    domain_name              = local.origins.fileflow_uploads.domain_name
    origin_id                = local.origins.fileflow_uploads.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # ----------------------------------------------------------------------------
  # Default Cache Behavior (stage-connectly)
  # ----------------------------------------------------------------------------
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.stage_connectly.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /otel-config/* -> stage-connectly
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/otel-config/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.stage_connectly.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 300  # 5 minutes (config files need faster updates)
    max_ttl     = 3600 # 1 hour
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /public/* -> fileflow-uploads-stage (public access)
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/public/*"
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
  # Cache Behavior: /internal/* -> fileflow-uploads-stage (Signed URL required)
  # Access without valid Signed URL returns 403
  # Backend generates CloudFront Signed URL and passes to client
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/internal/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.fileflow_uploads.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    trusted_key_groups = [aws_cloudfront_key_group.internal.id]

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
# Route53 Record for stage-cdn.set-of.com
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

# Policy for stage-connectly bucket (default + otel-config)
resource "aws_s3_bucket_policy" "stage-connectly" {
  bucket = "stage-connectly"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::stage-connectly",
          "arn:aws:s3:::stage-connectly/*"
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
        Resource  = "arn:aws:s3:::stage-connectly/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid       = "AllowCloudFrontDefault"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::stage-connectly/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

# Policy for fileflow-uploads-stage bucket (/public/* + /internal/*)
resource "aws_s3_bucket_policy" "fileflow-uploads" {
  bucket = "fileflow-uploads-stage"
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "PolicyForCloudFrontFileflowUploadsStage"
    Statement = [
      {
        Sid       = "AllowCloudFrontPublicFiles"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::fileflow-uploads-stage/public/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      },
      {
        Sid       = "AllowCloudFrontInternalFiles"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::fileflow-uploads-stage/internal/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}
