# Route53 Record for set-of.com apex domain
# Points to CloudFront redirect distribution

resource "aws_route53_record" "apex" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.source_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.www_redirect.domain_name
    zone_id                = aws_cloudfront_distribution.www_redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

# IPv6 record
resource "aws_route53_record" "apex_ipv6" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.source_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.www_redirect.domain_name
    zone_id                = aws_cloudfront_distribution.www_redirect.hosted_zone_id
    evaluate_target_health = false
  }
}
