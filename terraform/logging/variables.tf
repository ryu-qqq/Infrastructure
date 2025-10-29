# Central Logging System Variables

variable "aws_region" {
  description = "AWS region for CloudWatch Logs"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "owner" {
  description = "Owner email or identifier"
  type        = string
  default     = "fbtkdals2@naver.com"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "infrastructure"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
  default     = "terraform-state-bucket"
}
