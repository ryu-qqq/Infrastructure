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

# Admin CloudFront Distribution
output "admin_distribution_id" {
  description = "CloudFront distribution ID for admin (admin.set-of.com)"
  value       = aws_cloudfront_distribution.admin.id
}

output "admin_distribution_domain_name" {
  description = "CloudFront domain name for admin"
  value       = aws_cloudfront_distribution.admin.domain_name
}

# Route53 Records
output "route53_records" {
  description = "Route53 records managed by this module"
  value = {
    prod_apex = aws_route53_record.prod_apex.fqdn
    prod_www  = aws_route53_record.prod_www.fqdn
    admin     = aws_route53_record.admin.fqdn
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
    admin = {
      domains        = ["admin.set-of.com"]
      default_origin = "Gateway ALB (API only)"
      gateway_origin = data.aws_lb.gateway.dns_name
    }
  }
}
