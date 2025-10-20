# SNS Topic Module Variables

# Required Tags Variables
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "service" {
  description = "Service name that uses this SNS topic"
  type        = string
}

variable "team" {
  description = "Team responsible for this SNS topic"
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
  description = "Project name"
  type        = string
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
