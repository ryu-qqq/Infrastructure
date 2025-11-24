# ========================================
# ADOT Sidecar Module Variables
# ========================================

variable "project_name" {
  description = "Project name (e.g., crawlinghub, fileflow)"
  type        = string
}

variable "service_name" {
  description = "Service name (e.g., web-api, scheduler)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "cdn_host" {
  description = "CDN host for OTEL config (e.g., cdn.set-of.com)"
  type        = string
  default     = "cdn.set-of.com"
}

variable "config_bucket" {
  description = "S3 bucket name for OTEL configs"
  type        = string
  default     = "connectly-prod"
}

variable "amp_workspace_arn" {
  description = "Amazon Managed Prometheus workspace ARN"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name for ADOT logs"
  type        = string
}

variable "adot_cpu" {
  description = "CPU units for ADOT container"
  type        = number
  default     = 256
}

variable "adot_memory" {
  description = "Memory (MiB) for ADOT container"
  type        = number
  default     = 512
}
