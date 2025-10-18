# S3 Bucket Module Variables

# Required Variables

variable "bucket_name" {
  description = "Name of the S3 bucket (must follow kebab-case naming convention)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must follow kebab-case naming convention (lowercase alphanumeric and hyphens only)"
  }
}

# Required Tag Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "service" {
  description = "Service name"
  type        = string
}

variable "team" {
  description = "Team responsible for this resource"
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

# Optional Variables with Defaults

variable "kms_key_id" {
  description = "ARN of the KMS key to use for bucket encryption (required for governance compliance)"
  type        = string
  default     = null
}

variable "versioning_enabled" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "logging_enabled" {
  description = "Enable access logging for the S3 bucket"
  type        = bool
  default     = false
}

variable "logging_target_bucket" {
  description = "Target bucket for access logs (required if logging_enabled is true)"
  type        = string
  default     = null
}

variable "logging_target_prefix" {
  description = "Prefix for access log objects"
  type        = string
  default     = "logs/"
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules for the S3 bucket"
  type = list(object({
    id                           = string
    enabled                      = bool
    prefix                       = optional(string)
    expiration_days              = optional(number)
    transition_to_ia_days        = optional(number)
    transition_to_glacier_days   = optional(number)
    noncurrent_expiration_days   = optional(number)
    abort_incomplete_upload_days = optional(number)
  }))
  default = []
}

variable "cors_rules" {
  description = "List of CORS rules for the S3 bucket"
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = []
}

variable "block_public_acls" {
  description = "Block public ACLs on the bucket"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public bucket policies"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs on the bucket"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict public bucket policies"
  type        = bool
  default     = true
}

variable "enable_static_website" {
  description = "Enable static website hosting"
  type        = bool
  default     = false
}

variable "website_index_document" {
  description = "Index document for static website (e.g., index.html)"
  type        = string
  default     = "index.html"
}

variable "website_error_document" {
  description = "Error document for static website (e.g., error.html)"
  type        = string
  default     = "error.html"
}

variable "force_destroy" {
  description = "Allow deletion of non-empty bucket (use with caution in production)"
  type        = bool
  default     = false
}

variable "additional_tags" {
  description = "Additional tags to apply to the S3 bucket"
  type        = map(string)
  default     = {}
}

# Monitoring Variables

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for bucket monitoring"
  type        = bool
  default     = false
}

variable "alarm_bucket_size_threshold" {
  description = "Alarm threshold for bucket size in bytes (default: 100GB)"
  type        = number
  default     = 107374182400 # 100GB
}

variable "alarm_object_count_threshold" {
  description = "Alarm threshold for number of objects in bucket"
  type        = number
  default     = 1000000 # 1 million objects
}

variable "alarm_actions" {
  description = "SNS topic ARNs to notify when alarm triggers"
  type        = list(string)
  default     = []
}

variable "enable_request_metrics" {
  description = "Enable S3 Request Metrics for detailed monitoring"
  type        = bool
  default     = false
}

variable "request_metrics_filter_prefix" {
  description = "Prefix filter for request metrics (leave empty for entire bucket)"
  type        = string
  default     = ""
}

# Object Lock Variables

variable "enable_object_lock" {
  description = "Enable S3 Object Lock for WORM (Write Once Read Many) protection"
  type        = bool
  default     = false
}

variable "object_lock_mode" {
  description = "Object Lock mode: GOVERNANCE or COMPLIANCE"
  type        = string
  default     = "GOVERNANCE"
  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "Object Lock mode must be either GOVERNANCE or COMPLIANCE"
  }
}

variable "object_lock_retention_days" {
  description = "Default retention period in days for Object Lock"
  type        = number
  default     = null
}

variable "object_lock_retention_years" {
  description = "Default retention period in years for Object Lock"
  type        = number
  default     = null
}
