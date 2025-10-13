# Outputs for CloudTrail Module

# CloudTrail Outputs
output "cloudtrail_id" {
  description = "The ID of the CloudTrail trail"
  value       = aws_cloudtrail.main.id
}

output "cloudtrail_arn" {
  description = "The ARN of the CloudTrail trail"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_name" {
  description = "The name of the CloudTrail trail"
  value       = aws_cloudtrail.main.name
}

output "cloudtrail_home_region" {
  description = "The home region of the CloudTrail trail"
  value       = aws_cloudtrail.main.home_region
}

# S3 Bucket Outputs
output "cloudtrail_bucket_id" {
  description = "The ID of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_bucket_arn" {
  description = "The ARN of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "athena_results_bucket_id" {
  description = "The ID of the S3 bucket for Athena query results"
  value       = var.enable_athena ? aws_s3_bucket.athena_results[0].id : null
}

# KMS Outputs
output "cloudtrail_kms_key_id" {
  description = "The ID of the KMS key for CloudTrail logs"
  value       = aws_kms_key.cloudtrail.key_id
}

output "cloudtrail_kms_key_arn" {
  description = "The ARN of the KMS key for CloudTrail logs"
  value       = aws_kms_key.cloudtrail.arn
}

output "cloudtrail_kms_key_alias" {
  description = "The alias of the KMS key for CloudTrail logs"
  value       = aws_kms_alias.cloudtrail.name
}

# CloudWatch Logs Outputs
output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch Logs group"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.cloudtrail[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch Logs group"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.cloudtrail[0].arn : null
}

# Athena Outputs
output "athena_workgroup_name" {
  description = "The name of the Athena workgroup"
  value       = var.enable_athena ? aws_athena_workgroup.cloudtrail[0].name : null
}

output "athena_database_name" {
  description = "The name of the Glue database for CloudTrail logs"
  value       = var.enable_athena ? aws_glue_catalog_database.cloudtrail[0].name : null
}

output "athena_table_name" {
  description = "The name of the Glue table for CloudTrail logs"
  value       = var.enable_athena ? aws_glue_catalog_table.cloudtrail[0].name : null
}

# SNS Outputs
output "security_alerts_topic_arn" {
  description = "The ARN of the SNS topic for security alerts"
  value       = var.enable_security_alerts ? aws_sns_topic.security_alerts[0].arn : null
}

output "security_alerts_topic_name" {
  description = "The name of the SNS topic for security alerts"
  value       = var.enable_security_alerts ? aws_sns_topic.security_alerts[0].name : null
}

# Summary Output
output "cloudtrail_summary" {
  description = "Summary of CloudTrail configuration"
  value = {
    trail_name              = aws_cloudtrail.main.name
    trail_arn               = aws_cloudtrail.main.arn
    s3_bucket               = aws_s3_bucket.cloudtrail.id
    kms_key_alias           = aws_kms_alias.cloudtrail.name
    multi_region            = var.is_multi_region_trail
    log_file_validation     = var.enable_log_file_validation
    cloudwatch_logs_enabled = var.enable_cloudwatch_logs
    athena_enabled          = var.enable_athena
    security_alerts_enabled = var.enable_security_alerts
  }
}
