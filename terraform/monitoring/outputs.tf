# Outputs for Monitoring System

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
  value       = aws_iam_role.ecs_amp_writer.arn
}

output "ecs_amp_writer_role_name" {
  description = "IAM role name for ECS tasks to write to AMP"
  value       = aws_iam_role.ecs_amp_writer.name
}

output "grafana_amp_reader_role_arn" {
  description = "IAM role ARN for Grafana to read from AMP"
  value       = aws_iam_role.grafana_amp_reader.arn
}

output "grafana_amp_reader_role_name" {
  description = "IAM role name for Grafana to read from AMP"
  value       = aws_iam_role.grafana_amp_reader.name
}

# ============================================================================
# CloudWatch Log Group Outputs
# ============================================================================

output "amp_query_logs_name" {
  description = "CloudWatch Log Group name for AMP query logs"
  value       = var.amp_enable_logging ? aws_cloudwatch_log_group.amp_query_logs[0].name : null
}

output "amp_query_logs_arn" {
  description = "CloudWatch Log Group ARN for AMP query logs"
  value       = var.amp_enable_logging ? aws_cloudwatch_log_group.amp_query_logs[0].arn : null
}

# ============================================================================
# Configuration Outputs for Reference
# ============================================================================

output "adot_collector_config_template" {
  description = "ADOT Collector configuration reference"
  value = jsonencode({
    amp_endpoint    = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
    aws_region      = var.aws_region
    iam_role_arn    = aws_iam_role.ecs_amp_writer.arn
    workspace_id    = aws_prometheus_workspace.main.id
    scrape_interval = "30s"
  })
}

output "grafana_setup_info" {
  description = "Information for setting up Grafana data sources"
  value = {
    amp_data_source_url  = aws_prometheus_workspace.main.prometheus_endpoint
    amp_reader_role_arn  = aws_iam_role.grafana_amp_reader.arn
    grafana_endpoint     = aws_grafana_workspace.main.endpoint
    supported_data_types = var.amg_data_sources
  }
}
