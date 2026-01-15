# Route53 Record for Redirect
# Changes server.set-of.net from ALB to CloudFront

# ============================================================================
# Route53 Record
# ============================================================================

resource "aws_route53_record" "redirect" {
  zone_id         = local.route53_zone_id
  name            = var.source_domain
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

# IPv6 Record
resource "aws_route53_record" "redirect_ipv6" {
  zone_id = local.route53_zone_id
  name    = var.source_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
    evaluate_target_health = false
  }
}
