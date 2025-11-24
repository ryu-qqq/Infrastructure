# Variables for Secrets Manager Module

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "aws_region" {
  description = "AWS region for Secrets Manager"
  type        = string
  default     = "ap-northeast-2"
}

# Required Tags (Governance Standard)
variable "team" {
  description = "Team responsible for the resource"
  type        = string
  default     = "platform-team"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.team))
    error_message = "Team must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "owner" {
  description = "Owner email or identifier"
  type        = string
  default     = "platform-team"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner)) || can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.owner))
    error_message = "Owner must be a valid email address or kebab-case identifier."
  }
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "infrastructure"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cost_center))
    error_message = "Cost center must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "service" {
  description = "Service name this resource belongs to"
  type        = string
  default     = "secrets-manager"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service))
    error_message = "Service must use kebab-case (lowercase letters, numbers, hyphens only)."
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

variable "managed_by" {
  description = "How the resource is managed"
  type        = string
  default     = "terraform"
}

variable "data_class" {
  description = "Data classification level (confidential, internal, public)"
  type        = string
  default     = "highly-confidential"

  validation {
    condition     = contains(["highly-confidential", "confidential", "internal", "public"], var.data_class)
    error_message = "Data class must be one of: highly-confidential, confidential, internal, public."
  }
}

# Secrets Configuration
variable "secret_recovery_window_in_days" {
  description = "Number of days that Secrets Manager waits before permanently deleting a secret"
  type        = number
  default     = 30
  validation {
    condition     = var.secret_recovery_window_in_days >= 7 && var.secret_recovery_window_in_days <= 30
    error_message = "Recovery window must be between 7 and 30 days."
  }
}

variable "rotation_days" {
  description = "Number of days between automatic rotations"
  type        = number
  default     = 90
  validation {
    condition     = var.rotation_days >= 1 && var.rotation_days <= 365
    error_message = "Rotation days must be between 1 and 365."
  }
}

variable "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role for secrets access"
  type        = string
  default     = "GitHubActionsRole"
}

variable "enable_rotation" {
  description = "Enable automatic rotation for secrets"
  type        = bool
  default     = true
}

# Network Configuration for Lambda VPC
variable "vpc_id" {
  description = "VPC ID where Lambda will be deployed for RDS access"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Lambda VPC configuration"
  type        = list(string)
  default     = []
}

variable "rds_security_group_id" {
  description = "Security group ID of RDS instance to allow Lambda access"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "VPC CIDR block to restrict Lambda egress traffic"
  type        = string
  default     = ""
}
