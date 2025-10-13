# CloudWatch Log Group Module Variables

# Required Variables

variable "name" {
  description = "Name of the CloudWatch Log Group (must follow /aws/{service}/{resource}/{log-type} pattern)"
  type        = string
  validation {
    condition     = can(regex("^/aws/[a-z0-9-]+/[a-z0-9-]+(/[a-z0-9-]+)?$", var.name))
    error_message = "Log group name must follow the pattern: /aws/{service}/{resource}/{log-type}"
  }
}

variable "retention_in_days" {
  description = "Number of days to retain logs (0 = never expire)"
  type        = number
  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.retention_in_days)
    error_message = "Retention must be a valid CloudWatch Logs retention value"
  }
}

variable "common_tags" {
  description = "Common tags from common-tags module (Environment, Service, Team, Owner, CostCenter, ManagedBy, Project)"
  type        = map(string)
}

# Optional Variables with Defaults

variable "kms_key_id" {
  description = "ARN of the KMS key to use for log encryption (null = no encryption)"
  type        = string
  default     = null
}

variable "log_type" {
  description = "Type of logs stored in this group"
  type        = string
  default     = "application"
  validation {
    condition     = contains(["application", "errors", "llm", "access", "audit", "slowquery", "general"], var.log_type)
    error_message = "Log type must be one of: application, errors, llm, access, audit, slowquery, general"
  }
}

variable "export_to_s3_enabled" {
  description = "Whether S3 export is enabled for this log group"
  type        = bool
  default     = false
}

variable "sentry_sync_status" {
  description = "Sentry synchronization status"
  type        = string
  default     = "disabled"
  validation {
    condition     = contains(["pending", "enabled", "disabled"], var.sentry_sync_status)
    error_message = "Sentry sync status must be one of: pending, enabled, disabled"
  }
}

variable "langfuse_sync_status" {
  description = "Langfuse synchronization status"
  type        = string
  default     = "disabled"
  validation {
    condition     = contains(["pending", "enabled", "disabled"], var.langfuse_sync_status)
    error_message = "Langfuse sync status must be one of: pending, enabled, disabled"
  }
}

# Subscription Filter Variables (for future use)

variable "sentry_filter_pattern" {
  description = "CloudWatch Logs filter pattern for Sentry subscription"
  type        = string
  default     = "[timestamp, request_id, level=ERROR*, ...]"
}

variable "sentry_lambda_arn" {
  description = "ARN of the Lambda function for Sentry integration"
  type        = string
  default     = null
}

variable "langfuse_filter_pattern" {
  description = "CloudWatch Logs filter pattern for Langfuse subscription"
  type        = string
  default     = "[timestamp, request_id, model, ...]"
}

variable "langfuse_lambda_arn" {
  description = "ARN of the Lambda function for Langfuse integration"
  type        = string
  default     = null
}

# Metric Filter Variables

variable "enable_error_rate_metric" {
  description = "Whether to create a metric filter for error rate monitoring"
  type        = bool
  default     = false
}

variable "error_metric_pattern" {
  description = "Pattern to match errors for metric filter"
  type        = string
  default     = "[timestamp, request_id, level=ERROR*, ...]"
}

variable "metric_namespace" {
  description = "CloudWatch metric namespace for log metrics"
  type        = string
  default     = "CustomLogs"
}
