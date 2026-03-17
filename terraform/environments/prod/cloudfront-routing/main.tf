# ========================================
# CloudFront Distribution for API Gateway Routing - PROD
# ========================================
# Path-based routing:
#   /api/v1/* → Gateway ALB → Legacy API
#   /*        → Frontend ALB → Next.js
#
# Migrated from connectly-gateway repository.
# Existing resources imported via import blocks.
# ========================================

# ============================================================================
# Import Blocks (기존 리소스 import)
# ============================================================================
# connectly-gateway 레포에서 관리하던 리소스를 infrastructure로 이전
# import 완료 후 이 블록들은 제거 가능

import {
  to = aws_cloudfront_distribution.prod
  id = "E1DWFQ3MCX4AB8"
}

import {
  to = aws_cloudfront_cache_policy.api_no_cache
  id = "731b35f0-d9fa-4e25-8948-0c088d9420fa"
}

import {
  to = aws_cloudfront_cache_policy.public_static
  id = "aaadd050-a8e9-4f3b-aeb3-fa86351c4238"
}

import {
  to = aws_cloudfront_cache_policy.nextjs_image
  id = "c1d1a0e3-8098-4bea-9341-6c373963f4f1"
}

import {
  to = aws_cloudfront_origin_request_policy.api_all_viewer
  id = "53ed205f-c55c-43d2-b6c4-9eca49b6578b"
}

import {
  to = aws_cloudfront_response_headers_policy.api_cors
  id = "fd37cd93-5c19-475d-a9be-1edbe3ea0e8d"
}

import {
  to = aws_route53_record.prod_www
  id = "Z104656329CL6XBYE8OIJ_www.set-of.com_A"
}

# ============================================================================
# Cache Policies
# ============================================================================

# API Cache Policy - No caching
resource "aws_cloudfront_cache_policy" "api_no_cache" {
  name        = "gateway-api-no-cache-${var.environment}"
  comment     = "No caching for API requests - forward all to origin"
  min_ttl     = 0
  default_ttl = 0
  max_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

# Public Static Files Cache Policy
resource "aws_cloudfront_cache_policy" "public_static" {
  name        = "gateway-public-static-${var.environment}"
  comment     = "Cache policy for public static files - override Origin no-cache headers"
  min_ttl     = 3600
  default_ttl = 86400
  max_ttl     = 604800

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# Next.js Image Optimization Cache Policy
resource "aws_cloudfront_cache_policy" "nextjs_image" {
  name        = "gateway-nextjs-image-${var.environment}"
  comment     = "Cache policy for Next.js Image Optimization - includes query strings"
  min_ttl     = 0
  default_ttl = 86400
  max_ttl     = 31536000

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Accept"]
      }
    }
    query_strings_config {
      query_string_behavior = "all"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# ============================================================================
# Origin Request Policies
# ============================================================================

resource "aws_cloudfront_origin_request_policy" "api_all_viewer" {
  name    = "gateway-api-all-viewer-${var.environment}"
  comment = "Forward all viewer headers + X-Forwarded-For for API requests"

  cookies_config {
    cookie_behavior = "all"
  }
  headers_config {
    header_behavior = "allViewerAndWhitelistCloudFront"
    headers {
      items = [
        "CloudFront-Forwarded-Proto",
        "CloudFront-Is-Mobile-Viewer",
        "CloudFront-Viewer-Address",
      ]
    }
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}

# ============================================================================
# Response Headers Policy (CORS for API)
# ============================================================================

resource "aws_cloudfront_response_headers_policy" "api_cors" {
  name    = "gateway-api-cors-${var.environment}"
  comment = "CORS headers for API responses"

  cors_config {
    access_control_allow_credentials = true

    access_control_allow_headers {
      items = ["Authorization", "Content-Type", "X-Requested-With", "Accept", "Origin"]
    }

    access_control_allow_methods {
      items = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"]
    }

    access_control_allow_origins {
      items = [
        "https://set-of.com",
        "https://stage.set-of.com",
        "https://www.set-of.com",
        "https://admin.set-of.com",
        "https://oms.set-of.com",
      ]
    }

    access_control_max_age_sec = 86400

    origin_override = false
  }
}

# ============================================================================
# CloudFront Distribution - Production (set-of.com, www.set-of.com)
# ============================================================================
resource "aws_cloudfront_distribution" "prod" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "set-of.com - API Gateway routing"
  default_root_object = ""
  price_class         = "PriceClass_200"
  aliases             = ["www.set-of.com"]

  # ----------------------------------------------------------------------------
  # Origin 1: Frontend ALB (default)
  # ----------------------------------------------------------------------------
  origin {
    domain_name = data.aws_lb.frontend.dns_name
    origin_id   = "frontend-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ----------------------------------------------------------------------------
  # Origin 2: Gateway ALB (for /api/v1/*)
  # ----------------------------------------------------------------------------
  origin {
    domain_name = data.aws_lb.gateway.dns_name
    origin_id   = "gateway-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Forwarded-Host"
      value = "set-of.com"
    }
  }

  # ----------------------------------------------------------------------------
  # Default Cache Behavior → Frontend (HTML pages - no cache)
  # ----------------------------------------------------------------------------
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "frontend-alb"

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # ----------------------------------------------------------------------------
  # /_next/static/* → Frontend (long-term cache)
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern     = "/_next/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "frontend-alb"

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # ----------------------------------------------------------------------------
  # /_next/image/* → Frontend (with query string caching)
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern     = "/_next/image*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "frontend-alb"

    cache_policy_id          = aws_cloudfront_cache_policy.nextjs_image.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # ----------------------------------------------------------------------------
  # Public Static Files → Frontend (force cache)
  # ----------------------------------------------------------------------------
  dynamic "ordered_cache_behavior" {
    for_each = toset(local.public_static_paths)

    content {
      path_pattern     = ordered_cache_behavior.value
      allowed_methods  = ["GET", "HEAD"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "frontend-alb"

      cache_policy_id          = aws_cloudfront_cache_policy.public_static.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id

      viewer_protocol_policy = "redirect-to-https"
      compress               = true
    }
  }

  # ----------------------------------------------------------------------------
  # /api/v1/* → Gateway ALB
  # ----------------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern     = "/api/v1/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "gateway-alb"

    cache_policy_id            = aws_cloudfront_cache_policy.api_no_cache.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_all_viewer.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.api_cors.id

    viewer_protocol_policy = "https-only"
    compress               = false
  }

  # ----------------------------------------------------------------------------
  # SSL/TLS
  # ----------------------------------------------------------------------------
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.cloudfront.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-prod"
      Component = "cloudfront"
    }
  )
}

# ============================================================================
# Route53 Records
# ============================================================================

# set-of.com (apex) → SEO Redirect CloudFront (set-of.com → www.set-of.com)
# 별도의 SEO 리다이렉트 distribution(E3Z239SPRR9DP)이 이미 존재하므로 해당 distribution을 가리킴
# TODO: SEO 리다이렉트 distribution도 이 모듈에서 관리하도록 import 검토
resource "aws_route53_record" "prod_apex" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = data.aws_cloudfront_distribution.seo_redirect.domain_name
    zone_id                = data.aws_cloudfront_distribution.seo_redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

# www.set-of.com → CloudFront
resource "aws_route53_record" "prod_www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.prod.domain_name
    zone_id                = aws_cloudfront_distribution.prod.hosted_zone_id
    evaluate_target_health = false
  }
}

