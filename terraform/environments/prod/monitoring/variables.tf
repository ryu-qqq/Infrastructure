# Variables for Monitoring System (AMP/AMG)

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-2"
}

# Required Tags (Governance Standard)
variable "owner" {
  description = "Team or individual responsible for the resource"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
}

variable "resource_lifecycle" {
  description = "Resource lifecycle (permanent, temporary, ephemeral)"
  type        = string
  default     = "permanent"
}

variable "data_class" {
  description = "Data classification (public, internal, confidential, restricted)"
  type        = string
  default     = "internal"
}

variable "service" {
  description = "Service name this resource belongs to"
  type        = string
  default     = "monitoring"
}

variable "team" {
  description = "Team responsible for the resource"
  type        = string
  default     = "platform-team"
}

# Terraform State Configuration
variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "prod-connectly"
}

# AMP Configuration
variable "amp_workspace_alias" {
  description = "Alias for the AMP workspace"
  type        = string
  default     = "infrastructure-metrics"
}

variable "amp_retention_period" {
  description = "Retention period for AMP metrics in days"
  type        = number
  default     = 150
}

variable "amp_enable_logging" {
  description = "Enable CloudWatch Logs for AMP"
  type        = bool
  default     = true
}

# AMG Configuration
variable "amg_workspace_name" {
  description = "Name for the AMG workspace"
  type        = string
  default     = "infrastructure-observability"
}

variable "amg_account_access_type" {
  description = "Account access type for AMG (CURRENT_ACCOUNT or ORGANIZATION)"
  type        = string
  default     = "CURRENT_ACCOUNT"
}

variable "amg_authentication_providers" {
  description = "Authentication providers for AMG"
  type        = list(string)
  default     = ["AWS_SSO"]
}

variable "amg_permission_type" {
  description = "Permission type for AMG (SERVICE_MANAGED or CUSTOMER_MANAGED)"
  type        = string
  default     = "SERVICE_MANAGED"
}

variable "amg_data_sources" {
  description = "Data sources to enable in AMG"
  type        = list(string)
  default     = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]
}

# ADOT Configuration
variable "enable_adot_collector" {
  description = "Enable ADOT Collector sidecar for ECS"
  type        = bool
  default     = true
}

variable "adot_image_version" {
  description = "ADOT Collector image version"
  type        = string
  default     = "v0.42.0"
}

# CloudWatch Metrics Export
variable "enable_cloudwatch_metrics_export" {
  description = "Enable exporting CloudWatch metrics to AMP"
  type        = bool
  default     = true
}

variable "cloudwatch_metrics_namespaces" {
  description = "CloudWatch namespaces to export to AMP"
  type        = list(string)
  default     = ["AWS/ECS", "AWS/RDS", "AWS/ApplicationELB"]
}

# Alerting Configuration
variable "enable_ecs_alarms" {
  description = "Enable CloudWatch alarms for ECS resources"
  type        = bool
  default     = true
}

variable "enable_rds_alarms" {
  description = "Enable CloudWatch alarms for RDS resources"
  type        = bool
  default     = false # Will be enabled when RDS is deployed
}

variable "enable_alb_alarms" {
  description = "Enable CloudWatch alarms for ALB resources"
  type        = bool
  default     = false # Will be enabled when ALB is deployed
}

variable "enable_critical_email_alerts" {
  description = "Enable email notifications for critical alerts"
  type        = bool
  default     = false
}

variable "critical_alert_email" {
  description = "Email address for critical alert notifications"
  type        = string
  default     = ""
}

variable "slack_workspace_id" {
  description = "Slack Workspace ID for AWS Chatbot integration"
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_channel_id" {
  description = "Slack Channel ID for all alert notifications (can be split later if needed)"
  type        = string
  default     = "" # e.g., #alerts or #monitoring
  sensitive   = true
}

variable "enable_chatbot" {
  description = "Enable AWS Chatbot for Slack notifications"
  type        = bool
  default     = false # Will be enabled after Slack workspace setup
}

# ============================================================================
# Alert Enrichment Configuration
# ============================================================================

variable "enable_alert_enrichment" {
  description = "Enable alert enrichment Lambda for Slack notifications"
  type        = bool
  default     = false # Enable when Slack webhook is configured
}

variable "alert_enrichment_slack_webhook_url" {
  description = "Slack Incoming Webhook URL for enriched alerts"
  type        = string
  default     = ""
  sensitive   = true
}

variable "grafana_url" {
  description = "Grafana dashboard base URL for alert links"
  type        = string
  default     = ""
}

variable "enable_runbook_table" {
  description = "Enable DynamoDB table for runbook URL mappings"
  type        = bool
  default     = false
}

variable "enable_alert_history_table" {
  description = "Enable DynamoDB table for alert history"
  type        = bool
  default     = false
}

# ============================================================================
# OpenSearch Alerting Configuration
# ============================================================================

variable "enable_opensearch_alerting" {
  description = "Enable OpenSearch alerting with SNS notifications"
  type        = bool
  default     = false
}

variable "opensearch_domain_name" {
  description = "Name of the OpenSearch domain for log analysis"
  type        = string
  default     = "prod-obs-opensearch"
}

variable "run_opensearch_alerting_setup" {
  description = "Run the OpenSearch alerting setup Lambda to configure monitors"
  type        = bool
  default     = false
}

variable "opensearch_alerting_setup_version" {
  description = "Version string to trigger alerting setup re-run"
  type        = string
  default     = "v1"
}
