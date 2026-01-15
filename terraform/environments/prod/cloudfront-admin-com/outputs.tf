# Outputs for CloudFront Admin Com

output "distribution_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.admin.id
}

output "distribution_arn" {
  description = "CloudFront Distribution ARN"
  value       = aws_cloudfront_distribution.admin.arn
}

output "distribution_domain_name" {
  description = "CloudFront Distribution Domain Name"
  value       = aws_cloudfront_distribution.admin.domain_name
}

output "domain_name" {
  description = "Custom domain name"
  value       = var.domain_name
}

output "route53_record_fqdn" {
  description = "Route53 record FQDN"
  value       = aws_route53_record.admin.fqdn
}
