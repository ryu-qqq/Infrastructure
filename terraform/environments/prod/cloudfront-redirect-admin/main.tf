# CloudFront Proxy Distribution
# Proxies admin-server.set-of.net to gateway-alb (API Gateway)

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}

# ACM Certificate for *.set-of.net (must exist in us-east-1)
data "aws_acm_certificate" "wildcard" {
  provider    = aws.us_east_1
  domain      = "*.set-of.net"
  statuses    = ["ISSUED"]
  most_recent = true
}

# Route53 zone for set-of.net
data "aws_route53_zone" "net" {
  name = "set-of.net."
}

# ============================================================================
# CloudFront Distribution - API Proxy
# ============================================================================

resource "aws_cloudfront_distribution" "proxy" {
  comment         = "Proxy ${var.source_domain} to gateway-alb"
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = var.price_class
  aliases         = [var.source_domain]

  # Gateway ALB Origin
  origin {
    domain_name = var.gateway_alb_domain
    origin_id   = "gateway-alb"

    custom_header {
      name  = "X-Forwarded-Host"
      value = var.source_domain
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

  # Default cache behavior - proxy all requests to gateway
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "gateway-alb"
    viewer_protocol_policy = "https-only"
    compress               = false

    # API-optimized policies (no caching, forward all headers/cookies)
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    origin_request_policy_id   = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer
    response_headers_policy_id = var.cors_response_headers_policy_id
  }

  # SSL/TLS Configuration
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.wildcard.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # No geo restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Tags
  tags = merge(
    local.required_tags,
    {
      Name         = "${local.name_prefix}-distribution"
      Component    = "cloudfront"
      Purpose      = "api-proxy"
      SourceDomain = var.source_domain
    }
  )
}
