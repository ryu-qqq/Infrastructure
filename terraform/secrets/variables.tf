# Variables for Secrets Manager Module

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
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
}

variable "owner" {
  description = "Owner email or identifier"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "infrastructure"
}

variable "service" {
  description = "Service name this resource belongs to"
  type        = string
  default     = "secrets-manager"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "infrastructure"
}

variable "managed_by" {
  description = "How the resource is managed"
  type        = string
  default     = "terraform"
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
