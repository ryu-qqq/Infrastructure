# ============================================================================
# Required Variables
# ============================================================================

variable "log_group_name" {
  description = "Name of the CloudWatch Log Group to create subscription filter for"
  type        = string

  validation {
    condition     = can(regex("^/aws/", var.log_group_name)) || can(regex("^[a-zA-Z0-9_/-]+$", var.log_group_name))
    error_message = "Log group name must be a valid CloudWatch Log Group name."
  }
}

variable "service_name" {
  description = "Name of the service (used for naming the subscription filter)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.service_name))
    error_message = "Service name must be lowercase alphanumeric with hyphens only."
  }
}

# ============================================================================
# Optional Variables
# ============================================================================

variable "filter_name" {
  description = "Custom name for the subscription filter. If empty, defaults to '{service_name}-to-opensearch'"
  type        = string
  default     = ""
}

variable "filter_pattern" {
  description = <<-EOT
    CloudWatch Logs filter pattern to match log events.
    - Empty string "" matches all logs
    - Use filter pattern syntax for selective streaming

    Examples:
    - "" (all logs)
    - "ERROR" (logs containing ERROR)
    - "{ $.level = \"ERROR\" }" (JSON logs with level=ERROR)
    - "[ip, user, timestamp, request, status_code>=400, size]" (space-delimited with status >= 400)

    See: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html
  EOT
  type        = string
  default     = ""
}

variable "distribution" {
  description = <<-EOT
    Method for distributing log data to the destination.
    - "Random": Log data is distributed randomly (default)
    - "ByLogStream": Log data is grouped by log stream

    Use "ByLogStream" if you need to maintain ordering within a log stream.
  EOT
  type        = string
  default     = "Random"

  validation {
    condition     = contains(["Random", "ByLogStream"], var.distribution)
    error_message = "Distribution must be either 'Random' or 'ByLogStream'."
  }
}
