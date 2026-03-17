# ========================================
# Outputs
# ========================================

# Prod CloudFront Distribution
output "prod_distribution_id" {
  description = "CloudFront distribution ID for production (set-of.com, www.set-of.com)"
  value       = aws_cloudfront_distribution.prod.id
}

output "prod_distribution_domain_name" {
  description = "CloudFront domain name for production"
  value       = aws_cloudfront_distribution.prod.domain_name
}

# Route53 Records
output "route53_records" {
  description = "Route53 records managed by this module"
  value = {
    prod_apex = aws_route53_record.prod_apex.fqdn
    prod_www  = aws_route53_record.prod_www.fqdn
  }
}

# Routing Summary
output "routing_summary" {
  description = "Summary of CloudFront path-based routing configuration"
  value = {
    production = {
      domains         = ["set-of.com", "www.set-of.com"]
      default_origin  = "Frontend ALB (Next.js)"
      api_path        = "/api/v1/* → Gateway ALB"
      frontend_origin = data.aws_lb.frontend.dns_name
      gateway_origin  = data.aws_lb.gateway.dns_name
    }
  }
}
