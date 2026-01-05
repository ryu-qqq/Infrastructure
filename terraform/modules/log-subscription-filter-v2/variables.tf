# ============================================================================
# Log Subscription Filter V2 Variables
# ============================================================================

variable "log_group_name" {
  description = "CloudWatch Log Group name to subscribe"
  type        = string

  validation {
    condition     = can(regex("^/", var.log_group_name))
    error_message = "Log group name must start with '/'"
  }
}

variable "service_name" {
  description = "Service name for subscription filter naming (kebab-case)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "filter_pattern" {
  description = "CloudWatch Logs filter pattern (empty string = all logs)"
  type        = string
  default     = ""
}
