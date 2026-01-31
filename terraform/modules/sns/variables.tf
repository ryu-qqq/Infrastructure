# SNS Topic Module Variables

# Required Tags Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, staging, prod."
  }
}

variable "service" {
  description = "Service name that uses this SNS topic (kebab-case)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service))
    error_message = "Service name must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "team" {
  description = "Team responsible for this SNS topic (kebab-case)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.team))
    error_message = "Team must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "owner" {
  description = "Owner email or identifier"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner)) || can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.owner))
    error_message = "Owner must be a valid email address or kebab-case identifier."
  }
}

variable "cost_center" {
  description = "Cost center for billing (kebab-case)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cost_center))
    error_message = "Cost center must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "project" {
  description = "Project name"
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
  default     = "internal"

  validation {
    condition     = contains(["confidential", "internal", "public"], var.data_class)
    error_message = "Data class must be one of: confidential, internal, public."
  }
}

# SNS Topic Configuration
variable "name" {
  description = "Name of the SNS topic (without .fifo suffix for FIFO topics)"
  type        = string
}

variable "display_name" {
  description = "Display name for the SNS topic"
  type        = string
  default     = null
}

variable "fifo_topic" {
  description = "Whether the topic is a FIFO topic. If true, .fifo suffix will be added automatically"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enable content-based deduplication for FIFO topics"
  type        = bool
  default     = false
}

# Security
variable "kms_key_id" {
  description = "KMS key ID for encrypting messages. Required for all topics."
  type        = string
}

variable "topic_policy" {
  description = "IAM policy document for the SNS topic"
  type        = string
  default     = null
}

# Delivery Configuration
variable "delivery_policy" {
  description = "Delivery policy JSON for message retry configuration"
  type        = string
  default     = null
}

# Subscriptions
variable "subscriptions" {
  description = "Map of subscription configurations, where the key is a unique identifier for the subscription"
  type = map(object({
    protocol                        = string
    endpoint                        = string
    raw_message_delivery            = optional(bool)
    filter_policy                   = optional(map(list(string)))
    filter_policy_scope             = optional(string)
    delivery_policy                 = optional(string)
    redrive_policy                  = optional(string)
    confirmation_timeout_in_minutes = optional(number)
  }))
  default = {}
}

# CloudWatch Alarms
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarms"
  type        = number
  default     = 2
}

variable "alarm_period" {
  description = "Period in seconds for alarm evaluation"
  type        = number
  default     = 300
}

variable "alarm_messages_published_threshold" {
  description = "Threshold for low message publish rate alarm"
  type        = number
  default     = 1
}

variable "alarm_notifications_failed_threshold" {
  description = "Threshold for failed notifications alarm"
  type        = number
  default     = 1
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

variable "alarm_ok_actions" {
  description = "List of ARNs to notify when alarm clears"
  type        = list(string)
  default     = []
}

# Additional Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
