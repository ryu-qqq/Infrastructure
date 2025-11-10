# --- CloudFront Distribution Outputs ---

output "distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_hosted_zone_id" {
  description = "CloudFront Route 53 zone ID for alias records"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_status" {
  description = "Current status of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.status
}

output "distribution_etag" {
  description = "ETag of the CloudFront distribution (for updates)"
  value       = aws_cloudfront_distribution.this.etag
}

output "distribution_in_progress_validation_batches" {
  description = "Number of invalidation batches currently in progress"
  value       = aws_cloudfront_distribution.this.in_progress_validation_batches
}

output "distribution_last_modified_time" {
  description = "Last modified time of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.last_modified_time
}

output "distribution_caller_reference" {
  description = "Internal value used by CloudFront to allow future updates"
  value       = aws_cloudfront_distribution.this.caller_reference
}
