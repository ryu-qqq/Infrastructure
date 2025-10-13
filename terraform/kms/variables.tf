# Variables for KMS Module

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for KMS keys"
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
  default     = "kms"
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

# KMS Key Configuration
variable "key_deletion_window_in_days" {
  description = "Duration in days after which the key is deleted after destruction"
  type        = number
  default     = 30
  validation {
    condition     = var.key_deletion_window_in_days >= 7 && var.key_deletion_window_in_days <= 30
    error_message = "Key deletion window must be between 7 and 30 days."
  }
}

variable "enable_key_rotation" {
  description = "Enable automatic key rotation for KMS keys"
  type        = bool
  default     = true
}

variable "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role for KMS key access"
  type        = string
  default     = "GitHubActionsRole"
}
