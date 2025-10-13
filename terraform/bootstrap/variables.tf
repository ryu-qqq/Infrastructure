# Variables for Bootstrap Terraform Configuration
#
# This module creates the foundational resources (S3, DynamoDB, KMS)
# required for Terraform remote state management.

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-2"
}

# Required Tags (Governance Standard)
variable "owner" {
  description = "Team or individual responsible for the resource"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
}

variable "resource_lifecycle" {
  description = "Resource lifecycle (permanent, temporary, ephemeral)"
  type        = string
  default     = "permanent"
}

variable "data_class" {
  description = "Data classification (public, internal, confidential, restricted)"
  type        = string
  default     = "confidential"
}

variable "service" {
  description = "Service name this resource belongs to"
  type        = string
  default     = "terraform-backend"
}

# Backend Configuration
variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state storage"
  type        = string
  default     = "prod-connectly"
}

variable "state_lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "prod-connectly-tf-lock"
}

variable "state_bucket_versioning" {
  description = "Enable versioning on state bucket"
  type        = bool
  default     = true
}

variable "state_bucket_lifecycle_days" {
  description = "Days before transitioning old versions to Glacier"
  type        = number
  default     = 90
}

variable "state_bucket_expiration_days" {
  description = "Days before expiring old versions"
  type        = number
  default     = 365
}

# Locals for common tags
locals {
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.resource_lifecycle
    DataClass   = var.data_class
    Service     = var.service
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }

  bucket_name     = var.state_bucket_name
  lock_table_name = var.state_lock_table_name
}
