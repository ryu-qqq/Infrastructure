# ========================================
# Data Sources
# ========================================

# Route53 Hosted Zone
data "aws_route53_zone" "main" {
  name = "${var.domain_name}."
}

# ACM Certificate (CloudFront requires us-east-1)
data "aws_acm_certificate" "cloudfront" {
  provider    = aws.us_east_1
  domain      = var.domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}

# ========================================
# ALB References
# ========================================

# Gateway ALB (Stage - API routing target)
data "aws_lb" "gateway" {
  name = "gateway-alb-stage"
}

# Frontend ALB (Stage - Next.js)
data "aws_lb" "frontend" {
  name = "turbo-setof-web-stage"
}

# ========================================
# AWS Managed Cache Policies
# ========================================

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}
