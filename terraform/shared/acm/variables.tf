# ============================================================================
# Input Variables
# ============================================================================

# Project Configuration
variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# Certificate Configuration
variable "domain_name" {
  description = "Primary domain name for the certificate"
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domain names for the certificate (SANs)"
  type        = list(string)
  default     = []
}

variable "validation_method" {
  description = "Certificate validation method (DNS or EMAIL)"
  type        = string
  default     = "DNS"

  validation {
    condition     = contains(["DNS", "EMAIL"], var.validation_method)
    error_message = "Validation method must be DNS or EMAIL."
  }
}

# Route53 Configuration (for DNS validation)
variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID for DNS validation (required if validation_method is DNS)"
  type        = string
  default     = ""
}

variable "create_validation_records" {
  description = "Whether to automatically create Route53 DNS validation records"
  type        = bool
  default     = true
}

variable "wait_for_validation" {
  description = "Whether to wait for certificate validation to complete"
  type        = bool
  default     = true
}

# Governance Tags
variable "owner" {
  description = "Email of the team or individual responsible for this resource"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}

variable "data_class" {
  description = "Data classification (public, internal, confidential, sensitive)"
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "internal", "confidential", "sensitive"], var.data_class)
    error_message = "Data class must be public, internal, confidential, or sensitive."
  }
}

variable "resource_lifecycle" {
  description = "Resource lifecycle stage"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["development", "testing", "staging", "production"], var.resource_lifecycle)
    error_message = "Resource lifecycle must be development, testing, staging, or production."
  }
}
