# CloudFront Outputs

output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.cdn.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.cdn.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "cdn_url" {
  description = "CDN URL"
  value       = "https://${var.domain_name}"
}

output "origin_access_control_id" {
  description = "Origin Access Control ID"
  value       = aws_cloudfront_origin_access_control.s3.id
}

# URL Examples
output "url_examples" {
  description = "Example URLs for each origin"
  value = {
    default_origin  = "https://${var.domain_name}/some-file.jpg (connectly-prod bucket)"
    otel_config     = "https://${var.domain_name}/otel-config/service-name/otel-config.yaml (prod-connectly bucket)"
    fileflow_upload = "https://${var.domain_name}/uploads/image.jpg (fileflow-uploads-prod bucket)"
  }
}
