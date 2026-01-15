# Outputs for CloudFront www Redirect

output "distribution_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.www_redirect.id
}

output "distribution_domain_name" {
  description = "CloudFront Distribution domain name"
  value       = aws_cloudfront_distribution.www_redirect.domain_name
}

output "distribution_arn" {
  description = "CloudFront Distribution ARN"
  value       = aws_cloudfront_distribution.www_redirect.arn
}

output "function_arn" {
  description = "CloudFront Function ARN"
  value       = aws_cloudfront_function.www_redirect.arn
}

output "redirect_info" {
  description = "Redirect configuration summary"
  value = {
    source      = var.source_domain
    target      = var.target_domain
    status_code = 301
    type        = "SEO canonical redirect"
  }
}
