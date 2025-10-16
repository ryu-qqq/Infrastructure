variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "advanced-alb"
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "certificate_domain" {
  description = "Domain name for ACM certificate"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "enable_access_logs" {
  description = "Enable access logs for ALB"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket name for ALB access logs"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "Terraform"
    Example     = "advanced"
  }
}
