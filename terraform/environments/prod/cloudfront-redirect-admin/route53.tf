# Route53 Records for Admin Server API Proxy
# Points admin-server.set-of.net to CloudFront proxy distribution

resource "aws_route53_record" "proxy" {
  zone_id         = data.aws_route53_zone.net.zone_id
  name            = var.source_domain
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.proxy.domain_name
    zone_id                = aws_cloudfront_distribution.proxy.hosted_zone_id
    evaluate_target_health = false
  }
}

# IPv6 support
resource "aws_route53_record" "proxy_ipv6" {
  zone_id         = data.aws_route53_zone.net.zone_id
  name            = var.source_domain
  type            = "AAAA"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.proxy.domain_name
    zone_id                = aws_cloudfront_distribution.proxy.hosted_zone_id
    evaluate_target_health = false
  }
}
