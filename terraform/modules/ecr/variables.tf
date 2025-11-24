# --- Required Variables ---

variable "name" {
  description = "Name of the ECR repository"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-_/]*$", var.name)) && length(var.name) <= 256
    error_message = "Repository name must start with lowercase letter or number, contain only lowercase letters, numbers, hyphens, underscores, or forward slashes, and be 256 characters or less."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for ECR encryption"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "KMS key ARN must be a valid ARN starting with 'arn:aws:kms:'."
  }
}

# --- Required Variables (Tagging) ---

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
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

# --- Optional Variables (Repository Configuration) ---

variable "image_tag_mutability" {
  description = "Image tag mutability setting (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Image tag mutability must be either 'MUTABLE' or 'IMMUTABLE'."
  }
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

# --- Optional Variables (Lifecycle Policy) ---

variable "enable_lifecycle_policy" {
  description = "Enable lifecycle policy for automatic image cleanup"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Maximum number of tagged images to keep"
  type        = number
  default     = 30

  validation {
    condition     = var.max_image_count >= 1 && var.max_image_count <= 1000
    error_message = "Max image count must be between 1 and 1000."
  }
}

variable "lifecycle_tag_prefixes" {
  description = "Tag prefixes for lifecycle policy (e.g., ['v', 'release'])"
  type        = list(string)
  default     = ["v"]
}

variable "untagged_image_expiry_days" {
  description = "Number of days after which untagged images are deleted"
  type        = number
  default     = 7

  validation {
    condition     = var.untagged_image_expiry_days >= 1 && var.untagged_image_expiry_days <= 365
    error_message = "Untagged image expiry days must be between 1 and 365."
  }
}

# --- Optional Variables (Repository Policy) ---

variable "repository_policy" {
  description = "Custom repository policy JSON. If null, default policy is used."
  type        = string
  default     = null
}

variable "enable_default_policy" {
  description = "Enable default repository policy for same account access"
  type        = bool
  default     = true
}

# --- Optional Variables (Cross-Stack Reference) ---

variable "create_ssm_parameter" {
  description = "Create SSM parameter for cross-stack reference"
  type        = bool
  default     = true
}
