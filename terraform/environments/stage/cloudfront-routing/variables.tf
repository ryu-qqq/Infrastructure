# ========================================
# Variables
# ========================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "stage"
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = "set-of.com"
}
