# Messaging Pattern Module Variables

# Required Tags Variables
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "service" {
  description = "Service name that uses this messaging pattern"
  type        = string
}

variable "team" {
  description = "Team responsible for this messaging pattern"
  type        = string
}

variable "owner" {
  description = "Owner email or identifier"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}

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

# SNS Topic Configuration
variable "sns_topic_name" {
  description = "Name of the SNS topic for fan-out pattern"
  type        = string
}

variable "sns_display_name" {
  description = "Display name for the SNS topic"
  type        = string
  default     = null
}

variable "fifo_topic" {
  description = "Whether to use FIFO topic and queues"
  type        = bool
  default     = false
}

variable "sns_topic_policy" {
  description = "IAM policy document for the SNS topic"
  type        = string
  default     = null
}

# Security
variable "kms_key_id" {
  description = "KMS key ID for encrypting messages in SNS and SQS"
  type        = string
}

# SQS Queues Configuration
variable "sqs_queues" {
  description = "List of SQS queues to subscribe to the SNS topic"
  type = list(object({
    name                       = string
    visibility_timeout_seconds = optional(number, 30)
    message_retention_seconds  = optional(number, 345600)
    max_message_size           = optional(number, 262144)
    receive_wait_time_seconds  = optional(number, 0)
    enable_dlq                 = optional(bool, true)
    max_receive_count          = optional(number, 3)
    raw_message_delivery       = optional(bool, false)
    filter_policy              = optional(map(list(string)))
    additional_tags            = optional(map(string), {})
  }))

  validation {
    condition     = length(var.sqs_queues) == length(toset([for q in var.sqs_queues : q.name]))
    error_message = "The 'name' attribute for each queue in 'sqs_queues' must be unique."
  }
}

# CloudWatch Alarms
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
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
  description = "Additional tags to merge with common tags"
  type        = map(string)
  default     = {}
}
