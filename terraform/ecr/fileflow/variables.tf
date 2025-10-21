# Input Variables for ECR FileFlow

variable "aws_region" {
  description = "AWS region for ECR repository"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "platform-team@ryuqqq.com"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

variable "lifecycle" {
  description = "Lifecycle stage of the resources"
  type        = string
  default     = "production"
}

variable "data_class" {
  description = "Data classification level"
  type        = string
  default     = "confidential"
}

variable "image_tag_mutability" {
  description = "Image tag mutability setting (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "lifecycle_policy_max_image_count" {
  description = "Maximum number of images to keep"
  type        = number
  default     = 30
}
