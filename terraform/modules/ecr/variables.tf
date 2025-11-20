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

# --- Optional Variables (Repository Configuration) ---

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

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
