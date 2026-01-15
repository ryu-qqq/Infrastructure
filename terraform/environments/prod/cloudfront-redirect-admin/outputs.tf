# Outputs for Admin Server API Proxy

output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.proxy.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.proxy.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.proxy.domain_name
}

output "source_domain" {
  description = "Source domain being proxied"
  value       = var.source_domain
}

output "gateway_alb_domain" {
  description = "Gateway ALB domain (proxy target)"
  value       = var.gateway_alb_domain
}

output "route53_record_fqdn" {
  description = "Route53 record FQDN"
  value       = aws_route53_record.proxy.fqdn
}

output "proxy_info" {
  description = "Proxy configuration summary"
  value = {
    source = var.source_domain
    target = var.gateway_alb_domain
    type   = "API proxy to gateway-alb"
  }
}
