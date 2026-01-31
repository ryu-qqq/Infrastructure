# Variables for Route53 Record Module

# --- Required Variables (Tagging) ---
# Note: Route53 Records do not support tags, but these variables are included
# for consistency with other modules and potential future CloudWatch alarms

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

# --- Optional Variables (Tagging) ---

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

variable "additional_tags" {
  description = "Additional tags (for potential future use with CloudWatch alarms)"
  type        = map(string)
  default     = {}
}

# --- Required Variables (Route53 Configuration) ---

variable "zone_id" {
  description = "The ID of the hosted zone to create the record in"
  type        = string
}

variable "name" {
  description = "The name of the DNS record (e.g., 'www', 'api', or 'subdomain.example.com')"
  type        = string
}

variable "type" {
  description = "The record type (A, AAAA, CNAME, MX, TXT, etc.)"
  type        = string
  validation {
    condition     = contains(["A", "AAAA", "CNAME", "MX", "TXT", "NS", "SRV", "PTR", "SPF", "CAA"], var.type)
    error_message = "Record type must be one of: A, AAAA, CNAME, MX, TXT, NS, SRV, PTR, SPF, CAA"
  }
}

variable "ttl" {
  description = "The TTL of the record in seconds (not used for alias records)"
  type        = number
  default     = 300
}

variable "records" {
  description = "List of DNS record values (not used for alias records)"
  type        = list(string)
  default     = null
}

variable "alias_configuration" {
  description = "Alias configuration for AWS resource records (ALB, CloudFront, etc.)"
  type = object({
    name                   = string
    zone_id                = string
    evaluate_target_health = bool
  })
  default = null
}

variable "weighted_routing_policy" {
  description = "Weighted routing policy configuration"
  type = object({
    weight = number
  })
  default = null
}

variable "geolocation_routing_policy" {
  description = "Geolocation routing policy configuration"
  type = object({
    continent   = optional(string)
    country     = optional(string)
    subdivision = optional(string)
  })
  default = null
}

variable "failover_routing_policy" {
  description = "Failover routing policy configuration (PRIMARY or SECONDARY)"
  type = object({
    type = string
  })
  default = null
  validation {
    condition     = var.failover_routing_policy == null || contains(["PRIMARY", "SECONDARY"], var.failover_routing_policy.type)
    error_message = "Failover type must be either PRIMARY or SECONDARY"
  }
}

variable "set_identifier" {
  description = "Unique identifier for routing policy records"
  type        = string
  default     = null
}

variable "health_check_id" {
  description = "The ID of the health check to associate with this record"
  type        = string
  default     = null
}

variable "allow_overwrite" {
  description = "Allow overwriting existing records with the same name"
  type        = bool
  default     = false
}
