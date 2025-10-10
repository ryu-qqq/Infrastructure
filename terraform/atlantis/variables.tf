# Variables for Atlantis Terraform Configuration

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

variable "atlantis_version" {
  description = "Atlantis version to deploy"
  type        = string
  default     = "latest"
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

variable "lifecycle" {
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
  default     = "atlantis"
}

# Locals for common tags
locals {
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.lifecycle
    DataClass   = var.data_class
    Service     = var.service
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }
}
