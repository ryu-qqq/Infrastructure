# Python API Lambda Example Variables

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "service_name" {
  description = "Service name"
  type        = string
  default     = "example-api"
}

variable "vpc_id" {
  description = "VPC ID for Lambda deployment"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to Lambda deployment package (.zip file)"
  type        = string
  default     = "lambda_function.zip"
}

variable "custom_policy_arns" {
  description = "Map of custom IAM policy ARNs to attach to Lambda role"
  type        = map(string)
  default     = {}
}

variable "enable_api_gateway" {
  description = "Whether to enable API Gateway integration"
  type        = bool
  default     = false
}
