# ============================================
# Variables for Atlantis IAM Configuration
# ============================================

variable "atlantis_task_role_name" {
  description = "Name of the Atlantis ECS Task Role"
  type        = string
  default     = "atlantis-task-role"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-2"
}

# ============================================
# Required Tags Variables
# ============================================

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "infrastructure"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "shared"
}

variable "resource_lifecycle" {
  description = "Resource lifecycle stage"
  type        = string
  default     = "permanent"
}

variable "data_class" {
  description = "Data classification level"
  type        = string
  default     = "internal"
}

variable "service" {
  description = "Service name"
  type        = string
  default     = "atlantis"
}

# ============================================
# Locals
# ============================================

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
