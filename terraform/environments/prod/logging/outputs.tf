# Central Logging System Outputs

# ============================================================================
# Atlantis Log Groups
# ============================================================================

output "atlantis_application_log_group" {
  description = "Atlantis application log group details"
  value = {
    name              = module.atlantis_application_logs.log_group_name
    arn               = module.atlantis_application_logs.log_group_arn
    retention_in_days = module.atlantis_application_logs.retention_in_days
  }
}

output "atlantis_error_log_group" {
  description = "Atlantis error log group details"
  value = {
    name              = module.atlantis_error_logs.log_group_name
    arn               = module.atlantis_error_logs.log_group_arn
    retention_in_days = module.atlantis_error_logs.retention_in_days
  }
}

# ============================================================================
# Lambda Log Groups
# ============================================================================

output "secrets_rotation_log_group" {
  description = "Secrets Manager rotation Lambda log group details"
  value = {
    name              = module.secrets_rotation_logs.log_group_name
    arn               = module.secrets_rotation_logs.log_group_arn
    retention_in_days = module.secrets_rotation_logs.retention_in_days
  }
}

# ============================================================================
# Summary
# ============================================================================

output "log_groups_summary" {
  description = "Summary of all created log groups"
  value = {
    total_groups = length([
      module.atlantis_application_logs,
      module.atlantis_error_logs,
      module.secrets_rotation_logs
    ])
    groups = [
      {
        name      = module.atlantis_application_logs.log_group_name
        type      = "application"
        retention = module.atlantis_application_logs.retention_in_days
      },
      {
        name      = module.atlantis_error_logs.log_group_name
        type      = "errors"
        retention = module.atlantis_error_logs.retention_in_days
      },
      {
        name      = module.secrets_rotation_logs.log_group_name
        type      = "application"
        retention = module.secrets_rotation_logs.retention_in_days
      }
    ]
  }
}

output "kms_key_used" {
  description = "KMS key used for log encryption"
  value = {
    arn   = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn
    alias = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_alias
  }
}

# ============================================================================
# Log Streaming Outputs (Kinesis Data Streams)
# ============================================================================

output "kinesis_stream" {
  description = "Kinesis Data Stream for log routing"
  value = var.enable_log_streaming ? {
    name = aws_kinesis_stream.logs.name
    arn  = aws_kinesis_stream.logs.arn
  } : null
}

output "log_router_lambda" {
  description = "Lambda function for log routing to OpenSearch"
  value = var.enable_log_streaming ? {
    name = aws_lambda_function.log_router.function_name
    arn  = aws_lambda_function.log_router.arn
  } : null
}

output "log_router_dlq" {
  description = "DLQ for failed log routing records"
  value = var.enable_log_streaming ? {
    name = aws_sqs_queue.log_router_dlq.name
    arn  = aws_sqs_queue.log_router_dlq.arn
    url  = aws_sqs_queue.log_router_dlq.url
  } : null
}

output "opensearch_integration" {
  description = "OpenSearch integration details"
  value = var.enable_log_streaming ? {
    domain_name   = var.opensearch_domain_name
    domain_arn    = data.aws_opensearch_domain.logs[0].arn
    endpoint      = data.aws_opensearch_domain.logs[0].endpoint
    index_prefix  = var.opensearch_index_prefix
    index_pattern = "${var.opensearch_index_prefix}-{service}-YYYY-MM-DD"
  } : null
}

output "cloudwatch_to_kinesis_role" {
  description = "IAM role for CloudWatch Logs subscription filter"
  value = var.enable_log_streaming ? {
    name = aws_iam_role.cloudwatch_to_kinesis.name
    arn  = aws_iam_role.cloudwatch_to_kinesis.arn
  } : null
}
