# Route53 Records for admin.set-of.com
# Note: Route53 record may already exist, using allow_overwrite

# ============================================================================
# Route53 A Record (IPv4)
# ============================================================================

resource "aws_route53_record" "admin" {
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.admin.domain_name
    zone_id                = aws_cloudfront_distribution.admin.hosted_zone_id
    evaluate_target_health = false
  }
}

# ============================================================================
# Route53 AAAA Record (IPv6)
# ============================================================================

resource "aws_route53_record" "admin_ipv6" {
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = var.domain_name
  type            = "AAAA"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.admin.domain_name
    zone_id                = aws_cloudfront_distribution.admin.hosted_zone_id
    evaluate_target_health = false
  }
}
