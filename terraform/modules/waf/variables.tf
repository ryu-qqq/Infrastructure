# ==============================================================================
# Required Variables
# ==============================================================================

variable "name" {
  description = "Name of the WAF WebACL (kebab-case)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Name must be in kebab-case format (lowercase letters, numbers, and hyphens only)."
  }
}

variable "scope" {
  description = "Scope of the WAF WebACL (REGIONAL for ALB/API Gateway, CLOUDFRONT for CloudFront)"
  type        = string

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "Scope must be either REGIONAL or CLOUDFRONT."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, staging, prod."
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

# ==============================================================================
# OWASP Top 10 Rules Configuration
# ==============================================================================

variable "enable_owasp_rules" {
  description = "Enable AWS Managed OWASP Top 10 rules"
  type        = bool
  default     = true
}

variable "owasp_rules_priority" {
  description = "Priority for OWASP rules (lower number = higher priority)"
  type        = number
  default     = 10
}

# ==============================================================================
# Rate Limiting Configuration
# ==============================================================================

variable "enable_rate_limiting" {
  description = "Enable IP-based rate limiting"
  type        = bool
  default     = true
}

variable "rate_limit" {
  description = "Maximum number of requests per 5-minute period from a single IP"
  type        = number
  default     = 2000

  validation {
    condition     = var.rate_limit >= 100 && var.rate_limit <= 20000000
    error_message = "Rate limit must be between 100 and 20,000,000."
  }
}

variable "rate_limiting_priority" {
  description = "Priority for rate limiting rule"
  type        = number
  default     = 20
}

# ==============================================================================
# Geo Blocking Configuration
# ==============================================================================

variable "enable_geo_blocking" {
  description = "Enable geographic blocking"
  type        = bool
  default     = false
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for code in var.blocked_countries : can(regex("^[A-Z]{2}$", code))])
    error_message = "Country codes must be 2-letter uppercase ISO 3166-1 alpha-2 codes."
  }
}

variable "geo_blocking_priority" {
  description = "Priority for geo blocking rule"
  type        = number
  default     = 30
}

# ==============================================================================
# IP Reputation Rules
# ==============================================================================

variable "enable_ip_reputation" {
  description = "Enable AWS Managed IP reputation rules (blocks known bad IPs)"
  type        = bool
  default     = true
}

variable "ip_reputation_priority" {
  description = "Priority for IP reputation rule"
  type        = number
  default     = 40
}

# ==============================================================================
# Anonymous IP Rules
# ==============================================================================

variable "enable_anonymous_ip" {
  description = "Enable AWS Managed Anonymous IP rules (blocks VPN, proxy, Tor)"
  type        = bool
  default     = false
}

variable "anonymous_ip_priority" {
  description = "Priority for anonymous IP rule"
  type        = number
  default     = 50
}

# ==============================================================================
# Logging Configuration
# ==============================================================================

variable "enable_logging" {
  description = "Enable WAF logging to Kinesis Firehose"
  type        = bool
  default     = true
}

variable "log_destination_arn" {
  description = "ARN of Kinesis Firehose delivery stream for WAF logs (required if enable_logging is true)"
  type        = string
  default     = null

  validation {
    condition     = !var.enable_logging || var.log_destination_arn != null
    error_message = "log_destination_arn must be provided when enable_logging is true."
  }
}

variable "redacted_fields" {
  description = "Fields to redact in logs (e.g., authorization headers)"
  type = list(object({
    type = string # single_header, uri_path, query_string
    name = optional(string)
  }))
  default = []
}

# ==============================================================================
# CloudWatch Metrics Configuration
# ==============================================================================

variable "enable_cloudwatch_metrics" {
  description = "Enable CloudWatch metrics for WAF"
  type        = bool
  default     = true
}

variable "metric_name" {
  description = "CloudWatch metric name for the WebACL (defaults to WebACL name)"
  type        = string
  default     = null
}

# ==============================================================================
# Custom Rules
# ==============================================================================

variable "custom_rules" {
  description = "List of custom WAF rules to add"
  type = list(object({
    name     = string
    priority = number
    action   = string # allow, block, count
    statement = object({
      # Simplified - can be extended based on needs
      byte_match_statement = optional(object({
        field_to_match        = string
        positional_constraint = string
        search_string         = string
      }))
      geo_match_statement = optional(object({
        country_codes = list(string)
      }))
      ip_set_reference_statement = optional(object({
        arn = string
      }))
      rate_based_statement = optional(object({
        limit              = number
        aggregate_key_type = string
      }))
      size_constraint_statement = optional(object({
        field_to_match      = string
        comparison_operator = string
        size                = number
      }))
    })
    visibility_config = object({
      cloudwatch_metrics_enabled = bool
      metric_name                = string
      sampled_requests_enabled   = bool
    })
  }))
  default = []
}

# ==============================================================================
# Default Action
# ==============================================================================

variable "default_action" {
  description = "Default action for requests that don't match any rules (allow or block)"
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "Default action must be either allow or block."
  }
}

# ==============================================================================
# Resource Association (handled outside module typically)
# ==============================================================================

variable "resource_arns" {
  description = "List of resource ARNs to associate with this WAF (ALB, API Gateway, etc.)"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Advanced Configuration
# ==============================================================================

variable "description" {
  description = "Description of the WAF WebACL"
  type        = string
  default     = null
}

variable "sampled_requests_enabled" {
  description = "Enable sampled requests for all rules"
  type        = bool
  default     = true
}
