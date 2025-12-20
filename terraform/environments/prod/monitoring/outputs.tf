# Outputs for Monitoring System

# ============================================================================
# SNS Topic Outputs
# ============================================================================

output "sns_topic_critical_arn" {
  description = "ARN of the Critical severity SNS topic"
  value       = module.sns_critical.topic_arn
}

output "sns_topic_warning_arn" {
  description = "ARN of the Warning severity SNS topic"
  value       = module.sns_warning.topic_arn
}

output "sns_topic_info_arn" {
  description = "ARN of the Info severity SNS topic"
  value       = module.sns_info.topic_arn
}

# ============================================================================
# AMP Outputs
# ============================================================================

output "amp_workspace_id" {
  description = "Amazon Managed Prometheus workspace ID"
  value       = aws_prometheus_workspace.main.id
}

output "amp_workspace_arn" {
  description = "Amazon Managed Prometheus workspace ARN"
  value       = aws_prometheus_workspace.main.arn
}

output "amp_workspace_endpoint" {
  description = "Amazon Managed Prometheus workspace endpoint"
  value       = aws_prometheus_workspace.main.prometheus_endpoint
}

output "amp_workspace_remote_write_url" {
  description = "AMP remote write endpoint URL"
  value       = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
}

output "amp_workspace_query_url" {
  description = "AMP query endpoint URL"
  value       = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/query"
}

# ============================================================================
# AMG Outputs
# ============================================================================

output "amg_workspace_id" {
  description = "Amazon Managed Grafana workspace ID"
  value       = aws_grafana_workspace.main.id
}

output "amg_workspace_arn" {
  description = "Amazon Managed Grafana workspace ARN"
  value       = aws_grafana_workspace.main.arn
}

output "amg_workspace_endpoint" {
  description = "Amazon Managed Grafana workspace endpoint URL"
  value       = aws_grafana_workspace.main.endpoint
}

output "amg_workspace_grafana_version" {
  description = "Grafana version running in the workspace"
  value       = aws_grafana_workspace.main.grafana_version
}

# ============================================================================
# IAM Role Outputs
# ============================================================================

output "ecs_amp_writer_role_arn" {
  description = "IAM role ARN for ECS tasks to write to AMP"
  value       = module.iam_ecs_amp_writer.role_arn
}

output "ecs_amp_writer_role_name" {
  description = "IAM role name for ECS tasks to write to AMP"
  value       = module.iam_ecs_amp_writer.role_name
}

output "grafana_amp_reader_role_arn" {
  description = "IAM role ARN for Grafana to read from AMP"
  value       = module.iam_grafana_amp_reader.role_arn
}

output "grafana_amp_reader_role_name" {
  description = "IAM role name for Grafana to read from AMP"
  value       = module.iam_grafana_amp_reader.role_name
}

output "grafana_workspace_role_arn" {
  description = "IAM role ARN for Grafana workspace"
  value       = module.iam_grafana_workspace.role_arn
}

output "grafana_workspace_role_name" {
  description = "IAM role name for Grafana workspace"
  value       = module.iam_grafana_workspace.role_name
}

# ============================================================================
# CloudWatch Log Group Outputs
# ============================================================================

output "amp_query_logs_name" {
  description = "CloudWatch Log Group name for AMP query logs"
  value       = var.amp_enable_logging ? aws_cloudwatch_log_group.amp-query-logs[0].name : null
}

output "amp_query_logs_arn" {
  description = "CloudWatch Log Group ARN for AMP query logs"
  value       = var.amp_enable_logging ? aws_cloudwatch_log_group.amp-query-logs[0].arn : null
}

# ============================================================================
# Chatbot Outputs
# ============================================================================

output "chatbot_role_arn" {
  description = "ARN of the AWS Chatbot IAM role"
  value       = var.enable_chatbot ? module.iam_chatbot[0].role_arn : null
}

output "chatbot_config_arn" {
  description = "ARN of the Chatbot Slack configuration"
  value       = var.enable_chatbot && var.slack_channel_id != "" ? aws_chatbot_slack_channel_configuration.critical[0].chat_configuration_arn : null
  sensitive   = true
}

# ============================================================================
# Configuration Outputs for Reference
# ============================================================================

output "adot_collector_config_template" {
  description = "ADOT Collector configuration reference"
  value = jsonencode({
    amp_endpoint    = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
    aws_region      = local.aws_region
    iam_role_arn    = module.iam_ecs_amp_writer.role_arn
    workspace_id    = aws_prometheus_workspace.main.id
    scrape_interval = "30s"
  })
}

output "grafana_setup_info" {
  description = "Information for setting up Grafana data sources"
  value = {
    amp_data_source_url  = aws_prometheus_workspace.main.prometheus_endpoint
    amp_reader_role_arn  = module.iam_grafana_amp_reader.role_arn
    grafana_endpoint     = aws_grafana_workspace.main.endpoint
    supported_data_types = var.amg_data_sources
  }
}

# ============================================================================
# Alert Enrichment Outputs
# ============================================================================

output "alert_enrichment_lambda_arn" {
  description = "ARN of the alert enrichment Lambda function"
  value       = var.enable_alert_enrichment ? module.alert_enrichment_lambda[0].function_arn : null
}

output "alert_enrichment_lambda_name" {
  description = "Name of the alert enrichment Lambda function"
  value       = var.enable_alert_enrichment ? module.alert_enrichment_lambda[0].function_name : null
}

output "runbook_table_name" {
  description = "Name of the runbook DynamoDB table"
  value       = var.enable_runbook_table ? module.runbook_table[0].table_name : null
}

output "runbook_table_arn" {
  description = "ARN of the runbook DynamoDB table"
  value       = var.enable_runbook_table ? module.runbook_table[0].table_arn : null
}

output "alert_history_table_name" {
  description = "Name of the alert history DynamoDB table"
  value       = var.enable_alert_history_table ? module.alert_history_table[0].table_name : null
}

output "alert_history_table_arn" {
  description = "ARN of the alert history DynamoDB table"
  value       = var.enable_alert_history_table ? module.alert_history_table[0].table_arn : null
}
