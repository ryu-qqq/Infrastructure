# ========================================
# CloudFront Distribution for API Gateway Routing - STAGE
# ========================================
# Path-based routing:
#   /api/v1/* → Gateway ALB (Stage) → Legacy API
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
  to = aws_cloudfront_distribution.stage
  id = "E30SRE4EE0PFP3"
}

import {
  to = aws_cloudfront_distribution.admin_stage
  id = "E1DT88HGE47MQT"
}

import {
  to = aws_cloudfront_cache_policy.api_no_cache
  id = "84ad0c74-2341-40e4-857d-33e341ae2995"
}

import {
  to = aws_cloudfront_cache_policy.public_static
  id = "98602ef3-6f0e-455d-aeef-27fc66637fdd"
}

import {
  to = aws_cloudfront_cache_policy.nextjs_image
  id = "1a57be20-9737-40f3-85b3-4dcfd9a2da49"
}

import {
  to = aws_cloudfront_origin_request_policy.api_all_viewer
  id = "89194934-6e03-4ff9-b80f-493674b1418b"
}

import {
  to = aws_cloudfront_response_headers_policy.api_cors
  id = "7e7f75ab-054b-430f-b525-9d7637e39b17"
}

import {
  to = aws_cloudfront_response_headers_policy.admin_api_cors
  id = "4b5bc3bb-9d4c-4cd0-8ce4-42e55964be1e"
}

import {
  to = aws_wafv2_web_acl.admin_stage
  id = "d9c06327-98eb-4851-b6f9-040f10fb36ed/gateway-admin-waf-stage/CLOUDFRONT"
}

import {
  to = aws_route53_record.stage
  id = "Z104656329CL6XBYE8OIJ_stage.set-of.com_A"
}

import {
  to = aws_route53_record.admin_stage
  id = "Z104656329CL6XBYE8OIJ_stage-admin.set-of.com_A"
}

# ============================================================================
# Cache Policies
# ============================================================================

# API Cache Policy - No caching, forward all headers
resource "aws_cloudfront_cache_policy" "api_no_cache" {
  name        = "gateway-api-no-cache-${var.environment}"
  comment     = "No caching for API requests - forward all to origin (${var.environment})"
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
  comment     = "Cache policy for public static files (${var.environment})"
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
  comment     = "Cache policy for Next.js Image Optimization (${var.environment})"
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

# API Origin Request Policy - Forward all necessary headers
resource "aws_cloudfront_origin_request_policy" "api_all_viewer" {
  name    = "gateway-api-all-viewer-${var.environment}"
  comment = "Forward all viewer headers + X-Forwarded-For for API requests (${var.environment})"

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
# Response Headers Policies (CORS)
# ============================================================================

# CORS for Public API
resource "aws_cloudfront_response_headers_policy" "api_cors" {
  name    = "gateway-api-cors-${var.environment}"
  comment = "CORS headers for Public API responses (${var.environment})"

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
        "https://stage-oms.set-of.com",
      ]
    }

    access_control_expose_headers {
      items = ["X-New-Access-Token", "X-Trace-Id"]
    }

    access_control_max_age_sec = 86400

    origin_override = false
  }
}

# CORS for Admin API
resource "aws_cloudfront_response_headers_policy" "admin_api_cors" {
  name    = "gateway-admin-api-cors-${var.environment}"
  comment = "CORS headers for Admin API responses (${var.environment})"

  cors_config {
    access_control_allow_credentials = true

    access_control_allow_headers {
      items = ["Authorization", "Content-Type", "X-Requested-With", "Accept", "Origin"]
    }

    access_control_allow_methods {
      items = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"]
    }

    access_control_allow_origins {
      items = ["https://stage-admin.set-of.com", "https://admin.set-of.com"]
    }

    access_control_expose_headers {
      items = ["X-New-Access-Token", "X-Trace-Id"]
    }

    access_control_max_age_sec = 86400

    origin_override = false
  }
}

# ============================================================================
# CloudFront Distribution - stage.set-of.com
# ============================================================================
resource "aws_cloudfront_distribution" "stage" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "stage.set-of.com - API Gateway routing (Stage)"
  default_root_object = ""
  price_class         = "PriceClass_200"
  aliases             = ["stage.set-of.com"]

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
      value = "stage.set-of.com"
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
      Name      = "${local.name_prefix}-stage"
      Component = "cloudfront"
    }
  )
}

# ============================================================================
# WAFv2 WebACL for Admin CloudFront
# ============================================================================
# CloudFront 전용 WebACL은 us-east-1 리전에 생성 필요
resource "aws_wafv2_web_acl" "admin_stage" {
  provider    = aws.us_east_1
  name        = "gateway-admin-waf-${var.environment}"
  description = "WAF WebACL for Stage Admin CloudFront"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Common Rule Set (SQLi, XSS 등 기본 방어)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "gateway-admin-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs (Log4j, 악성 페이로드 방어)
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "gateway-admin-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Rate Limiting (분당 2000 요청 초과 시 차단)
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "gateway-admin-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "gateway-admin-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-admin-waf"
      Component = "waf"
    }
  )
}

# ============================================================================
# CloudFront Distribution - stage-admin.set-of.com
# ============================================================================
# Strangler Fig Pattern: 모든 요청 → Gateway ALB → Legacy Admin 또는 New Service
resource "aws_cloudfront_distribution" "admin_stage" {
  web_acl_id          = aws_wafv2_web_acl.admin_stage.arn
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "stage-admin.set-of.com - Admin API Gateway routing (Stage)"
  default_root_object = ""
  price_class         = "PriceClass_200"
  aliases             = ["stage-admin.set-of.com"]

  # ----------------------------------------------------------------------------
  # Origin: Gateway ALB
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
      value = "stage-admin.set-of.com"
    }
  }

  # ----------------------------------------------------------------------------
  # Default Cache Behavior → Gateway (API 전용, 캐싱 없음)
  # ----------------------------------------------------------------------------
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "gateway-alb"

    cache_policy_id            = aws_cloudfront_cache_policy.api_no_cache.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_all_viewer.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.admin_api_cors.id

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
      Name      = "${local.name_prefix}-admin"
      Component = "cloudfront"
    }
  )
}

# ============================================================================
# Route53 Records
# ============================================================================

# stage.set-of.com → CloudFront
# NOTE: 기존에 레거시 ALB를 바라보는 수동 레코드가 있음, import 또는 덮어쓰기 필요
resource "aws_route53_record" "stage" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "stage.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.stage.domain_name
    zone_id                = aws_cloudfront_distribution.stage.hosted_zone_id
    evaluate_target_health = false
  }
}

# www.stage.set-of.com → CloudFront
# TODO: ACM 인증서가 *.set-of.com (1단계)만 커버하므로
# www.stage.set-of.com (2단계)은 인증서에 SAN 추가 필요
# *.stage.set-of.com 또는 www.stage.set-of.com을 ACM에 추가 후 활성화
#
# resource "aws_route53_record" "www_stage" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "www.stage.${var.domain_name}"
#   type    = "A"
#
#   alias {
#     name                   = aws_cloudfront_distribution.stage.domain_name
#     zone_id                = aws_cloudfront_distribution.stage.hosted_zone_id
#     evaluate_target_health = false
#   }
# }

# stage-admin.set-of.com → CloudFront
resource "aws_route53_record" "admin_stage" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "stage-admin.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.admin_stage.domain_name
    zone_id                = aws_cloudfront_distribution.admin_stage.hosted_zone_id
    evaluate_target_health = false
  }
}
