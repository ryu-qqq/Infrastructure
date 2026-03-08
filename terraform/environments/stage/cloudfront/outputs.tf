# Stage CloudFront Outputs

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

output "key_group_id" {
  description = "CloudFront Key Group ID for Signed URL (backend integration)"
  value       = aws_cloudfront_key_group.internal.id
}

output "signed_url_key_pair_id" {
  description = "CloudFront Public Key ID for Signed URL generation"
  value       = aws_cloudfront_public_key.internal.id
}

output "signed_url_private_key_secret_arn" {
  description = "Secrets Manager ARN for Signed URL private key"
  value       = aws_secretsmanager_secret.cloudfront_private_key.arn
}
