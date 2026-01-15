# Outputs for CloudFront Redirect

output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.redirect.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.redirect.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.redirect.domain_name
}

output "cloudfront_function_arn" {
  description = "CloudFront Function ARN"
  value       = aws_cloudfront_function.redirect.arn
}

output "redirect_info" {
  description = "Redirect configuration"
  value = {
    source = "https://${var.source_domain}"
    target = "https://${var.target_domain}"
    status = "301 Moved Permanently"
  }
}

output "route53_record" {
  description = "Route53 record FQDN"
  value       = aws_route53_record.redirect.fqdn
}
