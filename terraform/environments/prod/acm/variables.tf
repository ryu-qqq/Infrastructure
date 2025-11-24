# Variables for ACM Certificate Management

# ==============================================================================
# Certificate Configuration
# ==============================================================================

variable "aws_region" {
  description = "AWS region for ACM certificate (must be us-east-1 for CloudFront)"
  type        = string
  default     = "ap-northeast-2"
}

variable "domain_name" {
  description = "Primary domain name for the certificate"
  type        = string
  default     = "set-of.com"
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID for DNS validation. If not provided, will lookup from SSM Parameter Store (/shared/route53/hosted-zone-id)"
  type        = string
  default     = ""
}

variable "enable_expiration_alarm" {
  description = "Enable CloudWatch alarm for certificate expiration monitoring"
  type        = bool
  default     = true
}

# ==============================================================================
# Required Tag Variables (Governance Standards)
# ==============================================================================

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "service" {
  description = "Service name (e.g., api, web, database, network)"
  type        = string
  default     = "certificate-management"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service))
    error_message = "Service must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "owner" {
  description = "Email or identifier of the resource owner"
  type        = string
  default     = "fbtkdals2@naver.com"
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner)) || can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.owner))
    error_message = "Owner must be a valid email address or kebab-case identifier."
  }
}

variable "cost_center" {
  description = "Cost center for billing and financial tracking"
  type        = string
  default     = "infrastructure"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cost_center))
    error_message = "Cost center must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "managed_by" {
  description = "How the resource is managed (e.g., terraform, manual, cloudformation)"
  type        = string
  default     = "terraform"
  validation {
    condition     = contains(["terraform", "manual", "cloudformation", "cdk"], var.managed_by)
    error_message = "Managed by must be one of: terraform, manual, cloudformation, cdk."
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
  description = "Additional tags to merge with required tags"
  type        = map(string)
  default     = {}
}
