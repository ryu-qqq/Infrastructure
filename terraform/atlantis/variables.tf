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
