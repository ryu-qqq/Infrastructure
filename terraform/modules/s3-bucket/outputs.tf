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

# Monitoring Outputs

output "cloudwatch_alarm_bucket_size_arn" {
  description = "ARN of the bucket size CloudWatch alarm"
  value       = var.enable_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.bucket-size[0].arn : null
}

output "cloudwatch_alarm_object_count_arn" {
  description = "ARN of the object count CloudWatch alarm"
  value       = var.enable_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.object-count[0].arn : null
}

output "request_metrics_name" {
  description = "Name of the S3 request metrics configuration"
  value       = var.enable_request_metrics ? aws_s3_bucket_metric.this[0].name : null
}

# Object Lock Outputs

output "object_lock_enabled" {
  description = "Whether Object Lock is enabled on the bucket"
  value       = var.enable_object_lock
}

output "object_lock_configuration" {
  description = "Object Lock configuration details"
  value = var.enable_object_lock ? {
    mode            = var.object_lock_mode
    retention_days  = var.object_lock_retention_days
    retention_years = var.object_lock_retention_years
  } : null
}
