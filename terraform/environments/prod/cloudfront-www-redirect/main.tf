# CloudFront www Redirect Distribution
# Redirects set-of.com (apex) to www.set-of.com (SEO canonical)
#
# IMPORTANT: Before applying this configuration:
# 1. Remove 'set-of.com' from the existing Distribution (E1DWFQ3MCX4AB8) aliases
#    - AWS Console > CloudFront > E1DWFQ3MCX4AB8 > General > Settings > Edit
#    - Remove 'set-of.com' from Alternate domain names (CNAMEs)
#    - Keep only 'www.set-of.com'
# 2. Then apply this Terraform configuration

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}

# ACM Certificate (covers both set-of.com and *.set-of.com)
data "aws_acm_certificate" "main" {
  provider    = aws.us_east_1
  domain      = "set-of.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

# Route53 Zone
data "aws_route53_zone" "main" {
  name = "set-of.com."
}

# ============================================================================
# CloudFront Function - Redirect Handler
# ============================================================================

resource "aws_cloudfront_function" "www_redirect" {
  name    = "redirect-apex-to-www"
  runtime = "cloudfront-js-2.0"
  publish = true
  comment = "Redirects set-of.com to www.set-of.com with path preservation (SEO canonical)"

  code = <<-EOF
function handler(event) {
  var request = event.request;
  var uri = request.uri || '/';

  // Build query string if exists
  var querystring = '';
  if (request.querystring && Object.keys(request.querystring).length > 0) {
    var params = [];
    for (var key in request.querystring) {
      var param = request.querystring[key];
      if (param.multiValue) {
        param.multiValue.forEach(function(v) {
          params.push(encodeURIComponent(key) + '=' + encodeURIComponent(v.value));
        });
      } else if (param.value) {
        params.push(encodeURIComponent(key) + '=' + encodeURIComponent(param.value));
      } else {
        params.push(encodeURIComponent(key));
      }
    }
    if (params.length > 0) {
      querystring = '?' + params.join('&');
    }
  }

  var redirectUrl = 'https://${var.target_domain}' + uri + querystring;

  return {
    statusCode: 301,
    statusDescription: 'Moved Permanently',
    headers: {
      'location': { value: redirectUrl },
      'cache-control': { value: 'max-age=86400' }
    }
  };
}
EOF
}

# ============================================================================
# CloudFront Distribution - Redirect Only
# ============================================================================

resource "aws_cloudfront_distribution" "www_redirect" {
  comment         = "SEO Redirect: ${var.source_domain} to ${var.target_domain}"
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  price_class     = var.price_class
  aliases         = [var.source_domain]

  # Dummy origin - CloudFront Function handles all requests before reaching origin
  origin {
    domain_name = var.target_domain
    origin_id   = "dummy-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default cache behavior with CloudFront Function
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "dummy-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = false

    # CloudFront Function association
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.www_redirect.arn
    }

    # Minimal caching - redirect responses are cached
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
  }

  # SSL/TLS Configuration
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.main.arn
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
      Purpose      = "seo-redirect"
      SourceDomain = var.source_domain
      TargetDomain = var.target_domain
    }
  )
}
