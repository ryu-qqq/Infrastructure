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
  default     = "v0.30.0"
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
  default     = "atlantis"
}

# ECS Task Configuration
variable "atlantis_cpu" {
  description = "CPU units for the Atlantis task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "atlantis_memory" {
  description = "Memory (MiB) for the Atlantis task"
  type        = number
  default     = 1024
}

variable "atlantis_container_port" {
  description = "Port the Atlantis container listens on"
  type        = number
  default     = 4141
}

variable "atlantis_repo_allowlist" {
  description = "Allowed repositories for Atlantis webhooks (e.g., github.com/your-org/*)"
  type        = string
  default     = "github.com/ryu-qqq/*"
}

variable "atlantis_url" {
  description = "The URL that Atlantis will be accessible at"
  type        = string
  default     = "https://atlantis.example.com"
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
}
