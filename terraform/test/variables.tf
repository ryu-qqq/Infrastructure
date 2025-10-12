# Variables for Atlantis test infrastructure

variable "aws_region" {
  description = "AWS region for test resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
}

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
  default     = "temporary"
}

variable "data_class" {
  description = "Data classification (public, internal, confidential, restricted)"
  type        = string
  default     = "internal"
}

variable "service" {
  description = "Service name this resource belongs to"
  type        = string
  default     = "atlantis-test"
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
    Purpose     = "atlantis-webhook-testing"
  }
}
