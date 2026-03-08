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
  # Origin: set-of.net (Legacy Images - migrated from deleted CloudFront)
  # ----------------------------------------------------------------------------
  origin {
    domain_name              = local.origins.setof_net_legacy.domain_name
    origin_id                = local.origins.setof_net_legacy.origin_id
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
    default_ttl = 300  # 5 minutes (config files need faster updates)
    max_ttl     = 3600 # 1 hour
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /public/* -> fileflow-uploads-prod (public access)
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
  # Cache Behavior: /internal/* -> fileflow-uploads-prod (Signed URL required)
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
  # Cache Behavior: /product/* -> set-of.net (Legacy Images)
  # Migrated from deleted CloudFront d3fej89xf1vai5.cloudfront.net
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/product/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /PRODUCT/* -> set-of.net (Legacy Images - uppercase)
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/PRODUCT/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /description/* -> set-of.net (Legacy Images)
  # Migrated from deleted CloudFront d3fej89xf1vai5.cloudfront.net
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/description/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /DESCRIPTION/* -> set-of.net (Legacy Images - uppercase)
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/DESCRIPTION/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /content/* -> set-of.net (Legacy Images)
  # Migrated from deleted CloudFront d3fej89xf1vai5.cloudfront.net
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/content/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /CONTENT/* -> set-of.net (Legacy Images - uppercase)
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/CONTENT/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /logo/* -> set-of.net (Legacy Images)
  # Migrated from deleted CloudFront d3fej89xf1vai5.cloudfront.net
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/logo/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /seo/* -> set-of.net (SEO files)
  # Migrated from deleted CloudFront d3fej89xf1vai5.cloudfront.net
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/seo/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /excel/* -> set-of.net (Excel files)
  # Added for legacy Excel file access (e.g., product_reg.xlsx)
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/excel/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /EXCEL/* -> set-of.net (Excel files - uppercase)
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/EXCEL/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /html/* -> set-of.net (Legacy HTML files)
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/html/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin

    min_ttl     = 0
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /HTML/* -> set-of.net (Legacy HTML files - uppercase)
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/HTML/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origins.setof_net_legacy.origin_id
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
# KMS Key Policy for CloudFront Access
# fileflow-uploads-prod bucket uses KMS encryption
# CloudFront OAC needs kms:Decrypt to serve encrypted objects
# ============================================================================

data "aws_kms_key" "fileflow_uploads" {
  key_id = "af78546f-6940-4ca8-83fa-29a9669fd270"
}

resource "aws_kms_key_policy" "fileflow_uploads_cloudfront" {
  key_id = data.aws_kms_key.fileflow_uploads.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid       = "EnableIAMUserPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::646886795421:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudFrontDecrypt"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

# ============================================================================
# S3 Bucket Policies for CloudFront Access
# ============================================================================

# Policy for connectly-prod bucket
resource "aws_s3_bucket_policy" "connectly-prod" {
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
resource "aws_s3_bucket_policy" "prod-connectly" {
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

# Policy for fileflow-uploads-prod bucket (/public/* + /internal/*)
resource "aws_s3_bucket_policy" "fileflow-uploads" {
  bucket = "fileflow-uploads-prod"
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "PolicyForCloudFrontFileflowUploads"
    Statement = [
      {
        Sid       = "AllowCloudFrontPublicFiles"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::fileflow-uploads-prod/public/*"
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
        Resource  = "arn:aws:s3:::fileflow-uploads-prod/internal/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

# ============================================================================
# Policy for set-of.net bucket (Legacy Images)
# Replaces old CloudFront OAI with new OAC
# Preserves: Jenkins CI/CD access, ELB logging
# ============================================================================
resource "aws_s3_bucket_policy" "setof-net-legacy" {
  bucket = "set-of.net"
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "PolicyForCloudFrontLegacyImages"
    Statement = [
      # CloudFront OAC access for legacy image paths
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource = [
          "arn:aws:s3:::set-of.net/product/*",
          "arn:aws:s3:::set-of.net/PRODUCT/*",
          "arn:aws:s3:::set-of.net/description/*",
          "arn:aws:s3:::set-of.net/DESCRIPTION/*",
          "arn:aws:s3:::set-of.net/content/*",
          "arn:aws:s3:::set-of.net/CONTENT/*",
          "arn:aws:s3:::set-of.net/logo/*",
          "arn:aws:s3:::set-of.net/seo/*",
          "arn:aws:s3:::set-of.net/excel/*",
          "arn:aws:s3:::set-of.net/EXCEL/*",
          "arn:aws:s3:::set-of.net/html/*",
          "arn:aws:s3:::set-of.net/HTML/*"
        ]
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      },
      # Preserve: Jenkins CI/CD access
      {
        Sid       = "AllowJenkinsCICD"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::646886795421:user/setof-jenkins-cicd" }
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::set-of.net/*"
      },
      # Preserve: ELB logging
      {
        Sid       = "AllowELBLogging"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::582318560864:root" }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::set-of.net/AWSLogs/646886795421/elasticloadbalancing/*"
      },
      {
        Sid       = "AllowELBLoggingService"
        Effect    = "Allow"
        Principal = { Service = "elasticloadbalancing.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::set-of.net/AWSLogs/646886795421/elasticloadbalancing/*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = "646886795421" }
          ArnLike      = { "aws:SourceArn" = "arn:aws:elasticloadbalancing:ap-northeast-2:646886795421:loadbalancer/app/setof-front-load-balancer/0c4ec80e817a0f8b" }
        }
      }
    ]
  })
}
