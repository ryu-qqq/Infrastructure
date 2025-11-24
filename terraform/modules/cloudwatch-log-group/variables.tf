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

# Required Tag Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "service_name" {
  description = "Service name (kebab-case, e.g., api-server, web-app)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "team" {
  description = "Team responsible for the resource (kebab-case, e.g., platform-team)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.team))
    error_message = "Team must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "owner" {
  description = "Email or identifier of the resource owner"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner)) || can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.owner))
    error_message = "Owner must be a valid email address or kebab-case identifier."
  }
}

variable "cost_center" {
  description = "Cost center for billing and financial tracking (kebab-case)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cost_center))
    error_message = "Cost center must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

# Optional Tag Variables
variable "project" {
  description = "Project name this resource belongs to"
  type        = string
  default     = "infrastructure"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project))
    error_message = "Project must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "data_class" {
  description = "Data classification level (confidential, internal, public)"
  type        = string
  default     = "confidential"

  validation {
    condition     = contains(["confidential", "internal", "public"], var.data_class)
    error_message = "Data class must be one of: confidential, internal, public."
  }
}

variable "additional_tags" {
  description = "Additional tags to merge with common tags"
  type        = map(string)
  default     = {}
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
