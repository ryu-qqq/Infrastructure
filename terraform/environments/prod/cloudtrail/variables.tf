# Variables for CloudTrail Module

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region for CloudTrail resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

# --- Required Tags (Governance Standard) ---

variable "team" {
  description = "Team responsible for the resource (kebab-case, e.g., platform-team)"
  type        = string
  default     = "platform-team"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.team))
    error_message = "Team must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "owner" {
  description = "Owner email or identifier"
  type        = string
  default     = "platform-team"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner)) || can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.owner))
    error_message = "Owner must be a valid email address or kebab-case identifier."
  }
}

variable "cost_center" {
  description = "Cost center for billing allocation (kebab-case)"
  type        = string
  default     = "infrastructure"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cost_center))
    error_message = "Cost center must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "service_name" {
  description = "Service name (kebab-case, e.g., cloudtrail, security-audit)"
  type        = string
  default     = "cloudtrail"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "project" {
  description = "Project name (kebab-case)"
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

# CloudTrail Configuration
variable "cloudtrail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
  default     = "central-cloudtrail"
}

variable "enable_log_file_validation" {
  description = "Enable CloudTrail log file validation"
  type        = bool
  default     = true
}

variable "include_global_service_events" {
  description = "Include global service events (IAM, STS, etc)"
  type        = bool
  default     = true
}

variable "is_multi_region_trail" {
  description = "Make this trail multi-region"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs delivery"
  type        = bool
  default     = true
}

variable "enable_s3_data_events" {
  description = "Enable S3 data events logging (WARNING: Can generate massive costs)"
  type        = bool
  default     = false
}

variable "enable_lambda_data_events" {
  description = "Enable Lambda data events logging (WARNING: Can generate massive costs)"
  type        = bool
  default     = false
}

# S3 Bucket Configuration
variable "s3_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  type        = string
  default     = "cloudtrail-logs"
}

variable "s3_key_prefix" {
  description = "S3 key prefix for CloudTrail logs"
  type        = string
  default     = "cloudtrail"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudTrail logs in S3"
  type        = number
  default     = 90
}

# Athena Configuration
variable "enable_athena" {
  description = "Enable Athena for CloudTrail log analysis"
  type        = bool
  default     = true
}

variable "athena_database_name" {
  description = "Name of the Athena database for CloudTrail logs"
  type        = string
  default     = "cloudtrail_logs"
}

variable "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  type        = string
  default     = "cloudtrail-analysis"
}

# Event Notifications
variable "enable_security_alerts" {
  description = "Enable security event alerts via SNS"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for security alerts"
  type        = string
  default     = ""
}

# KMS Configuration
variable "kms_key_deletion_window_in_days" {
  description = "Duration in days after which the KMS key is deleted"
  type        = number
  default     = 30
}

variable "enable_kms_key_rotation" {
  description = "Enable automatic KMS key rotation"
  type        = bool
  default     = true
}
