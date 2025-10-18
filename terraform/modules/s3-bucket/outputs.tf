# S3 Bucket Module Outputs

output "bucket_id" {
  description = "The ID (name) of the bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The ARN of the bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_region" {
  description = "The AWS region this bucket resides in"
  value       = aws_s3_bucket.this.region
}

output "website_endpoint" {
  description = "The website endpoint, if the bucket is configured with a website"
  value       = var.enable_static_website ? aws_s3_bucket_website_configuration.this[0].website_endpoint : null
}

output "website_domain" {
  description = "The domain of the website endpoint, if the bucket is configured with a website"
  value       = var.enable_static_website ? aws_s3_bucket_website_configuration.this[0].website_domain : null
}

output "bucket_tags" {
  description = "The tags applied to the bucket"
  value       = aws_s3_bucket.this.tags_all
}
