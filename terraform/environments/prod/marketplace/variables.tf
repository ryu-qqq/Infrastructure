# Variables for Marketplace IAM Module

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "service_name" {
  description = "Service name"
  type        = string
  default     = "marketplace"
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
  default     = "marketplace"
}
