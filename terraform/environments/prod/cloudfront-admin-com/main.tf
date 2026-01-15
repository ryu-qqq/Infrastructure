# CloudFront Distribution for Admin
# admin.set-of.com - Multi-origin configuration (same pattern as www.set-of.com)
# - /api/v1/* → gateway-alb (API Backend)
# - /* (default) → frontend-alb (Admin Frontend)

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}

# ACM Certificate (must be in us-east-1 for CloudFront)
data "aws_acm_certificate" "wildcard" {
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
# CloudFront Distribution
# ============================================================================

resource "aws_cloudfront_distribution" "admin" {
  comment         = "admin.set-of.com - Admin Multi-origin routing"
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2"
  price_class     = var.price_class
  aliases         = [var.domain_name]

  # ----------------------------------------------------------------------------
  # Origin: Gateway ALB (API Backend)
  # ----------------------------------------------------------------------------
  origin {
    domain_name = local.origins.gateway_alb.domain_name
    origin_id   = local.origins.gateway_alb.origin_id

    custom_header {
      name  = "X-Forwarded-Host"
      value = var.domain_name
    }

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
    }
  }

  # ----------------------------------------------------------------------------
  # Origin: Admin Frontend ALB
  # ----------------------------------------------------------------------------
  origin {
    domain_name = local.origins.admin_frontend_alb.domain_name
    origin_id   = local.origins.admin_frontend_alb.origin_id

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
    }
  }

  # ----------------------------------------------------------------------------
  # Default Cache Behavior - Frontend (frontend-alb)
  # ----------------------------------------------------------------------------
  default_cache_behavior {
    target_origin_id       = local.origins.admin_frontend_alb.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    # CachingDisabled + AllViewer (for dynamic frontend)
    cache_policy_id          = local.cache_policies.caching_disabled
    origin_request_policy_id = local.origin_request_policies.all_viewer
  }

  # ----------------------------------------------------------------------------
  # Cache Behavior: /api/v1/* → gateway-alb (API)
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/api/v1/*"
    target_origin_id       = local.origins.gateway_alb.origin_id
    viewer_protocol_policy = "https-only"
    compress               = false

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    # Same policies as www.set-of.com API routing
    cache_policy_id            = local.cache_policies.api_cache
    origin_request_policy_id   = local.origin_request_policies.api_origin
    response_headers_policy_id = local.response_headers_policies.api_response
  }

  # ----------------------------------------------------------------------------
  # SSL/TLS Configuration
  # ----------------------------------------------------------------------------
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.wildcard.arn
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
      Purpose   = "admin-multi-origin"
    }
  )
}
