# DynamoDB Module Variables

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
  description = "Service name"
  type        = string
}

variable "team" {
  description = "Team responsible for the resource"
  type        = string
}

variable "owner" {
  description = "Owner email address"
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
  default     = "internal"

  validation {
    condition     = contains(["confidential", "internal", "public"], var.data_class)
    error_message = "Data class must be one of: confidential, internal, public."
  }
}

# Table Configuration
variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.table_name))
    error_message = "Table name must contain only alphanumeric characters, underscores, hyphens, and periods."
  }
}

variable "billing_mode" {
  description = "Billing mode for the table (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "Billing mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "read_capacity" {
  description = "Read capacity units (only for PROVISIONED billing mode)"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Write capacity units (only for PROVISIONED billing mode)"
  type        = number
  default     = 5
}

# Key Configuration
variable "hash_key" {
  description = "Attribute name for the hash key (partition key)"
  type        = string
}

variable "range_key" {
  description = "Attribute name for the range key (sort key)"
  type        = string
  default     = null
}

variable "attributes" {
  description = "List of attribute definitions"
  type = list(object({
    name = string
    type = string # S (String), N (Number), B (Binary)
  }))

  validation {
    condition     = alltrue([for attr in var.attributes : contains(["S", "N", "B"], attr.type)])
    error_message = "Attribute type must be S (String), N (Number), or B (Binary)."
  }
}

# Secondary Indexes
variable "global_secondary_indexes" {
  description = "List of Global Secondary Index definitions"
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = optional(string)
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string))
    read_capacity      = optional(number)
    write_capacity     = optional(number)
  }))
  default = []
}

variable "local_secondary_indexes" {
  description = "List of Local Secondary Index definitions"
  type = list(object({
    name               = string
    range_key          = string
    projection_type    = optional(string, "ALL")
    non_key_attributes = optional(list(string))
  }))
  default = []
}

# TTL Configuration
variable "ttl_attribute_name" {
  description = "Name of the TTL attribute (null to disable TTL)"
  type        = string
  default     = null
}

# Encryption
variable "kms_key_arn" {
  description = "ARN of the KMS key for server-side encryption (required)"
  type        = string
}

# Point-in-Time Recovery
variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

# Streams
variable "stream_enabled" {
  description = "Enable DynamoDB Streams"
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "Stream view type (KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES)"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"

  validation {
    condition     = contains(["KEYS_ONLY", "NEW_IMAGE", "OLD_IMAGE", "NEW_AND_OLD_IMAGES"], var.stream_view_type)
    error_message = "Stream view type must be one of: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES."
  }
}

# Deletion Protection
variable "deletion_protection_enabled" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

# Auto Scaling (for PROVISIONED mode)
variable "enable_autoscaling" {
  description = "Enable auto scaling (only for PROVISIONED billing mode)"
  type        = bool
  default     = false
}

variable "autoscaling_read_min_capacity" {
  description = "Minimum read capacity for auto scaling"
  type        = number
  default     = 5
}

variable "autoscaling_read_max_capacity" {
  description = "Maximum read capacity for auto scaling"
  type        = number
  default     = 100
}

variable "autoscaling_write_min_capacity" {
  description = "Minimum write capacity for auto scaling"
  type        = number
  default     = 5
}

variable "autoscaling_write_max_capacity" {
  description = "Maximum write capacity for auto scaling"
  type        = number
  default     = 100
}

variable "autoscaling_target_value" {
  description = "Target utilization percentage for auto scaling"
  type        = number
  default     = 70
}

# Additional Tags
variable "additional_tags" {
  description = "Additional tags to merge with common tags"
  type        = map(string)
  default     = {}
}
