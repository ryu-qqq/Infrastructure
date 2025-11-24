# Local values for CloudTrail Module

locals {
  # Full S3 bucket name with account ID
  cloudtrail_bucket_name = "${var.s3_bucket_name}-${var.aws_account_id}"

  # Athena query result bucket
  athena_result_bucket_name = "athena-query-results-${var.aws_account_id}"

  # CloudWatch Logs group name
  cloudwatch_log_group_name = "/aws/cloudtrail/${var.cloudtrail_name}"

  # SNS topic name for security alerts
  security_alerts_topic_name = "cloudtrail-security-alerts"

  # Required tags for all resources
  required_tags = {
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}
