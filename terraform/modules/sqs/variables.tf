# SQS Queue Module Variables

# Required Tags Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "service" {
  description = "Service name that uses this SQS queue (kebab-case)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service))
    error_message = "Service name must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "team" {
  description = "Team responsible for this SQS queue (kebab-case)"
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

# SQS Queue Configuration
variable "name" {
  description = "Name of the SQS queue (without .fifo suffix for FIFO queues)"
  type        = string
}

variable "fifo_queue" {
  description = "Whether the queue is a FIFO queue. If true, .fifo suffix will be added automatically"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enable content-based deduplication for FIFO queues"
  type        = bool
  default     = false
}

# Security
variable "kms_key_id" {
  description = "KMS key ID for encrypting messages. Required for all queues."
  type        = string
}

variable "kms_data_key_reuse_period_seconds" {
  description = "The length of time that Amazon SQS can reuse a data key before calling KMS again"
  type        = number
  default     = 300
}

variable "queue_policy" {
  description = "IAM policy document for the SQS queue"
  type        = string
  default     = null
}

# Message Configuration
variable "visibility_timeout_seconds" {
  description = "The visibility timeout for the queue in seconds"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message (60-1209600, default 345600 = 4 days)"
  type        = number
  default     = 345600
}

variable "max_message_size" {
  description = "The maximum message size in bytes (1024-262144, default 262144 = 256 KB)"
  type        = number
  default     = 262144
}

variable "delay_seconds" {
  description = "The delay in seconds for message delivery"
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "The time for which a ReceiveMessage call waits for a message (long polling)"
  type        = number
  default     = 0
}

# FIFO-specific Configuration
variable "deduplication_scope" {
  description = "Deduplication scope for FIFO queues (messageGroup or queue)"
  type        = string
  default     = "queue"
}

variable "fifo_throughput_limit" {
  description = "Throughput limit for FIFO queues (perQueue or perMessageGroupId)"
  type        = string
  default     = "perQueue"
}

# Dead Letter Queue (DLQ) Configuration
variable "enable_dlq" {
  description = "Enable Dead Letter Queue for failed messages"
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "Maximum number of receives before sending to DLQ"
  type        = number
  default     = 3
}

variable "dlq_message_retention_seconds" {
  description = "Message retention for DLQ in seconds (default 1209600 = 14 days)"
  type        = number
  default     = 1209600
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

variable "alarm_message_age_threshold" {
  description = "Threshold in seconds for message age alarm (default 300 = 5 minutes)"
  type        = number
  default     = 300
}

variable "alarm_messages_visible_threshold" {
  description = "Threshold for number of visible messages alarm"
  type        = number
  default     = 100
}

variable "alarm_dlq_messages_threshold" {
  description = "Threshold for DLQ messages alarm (any message in DLQ triggers alarm)"
  type        = number
  default     = 0
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
