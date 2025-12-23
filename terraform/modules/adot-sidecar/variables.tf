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
  default     = "prod-connectly"
}

variable "amp_workspace_arn" {
  description = "Amazon Managed Prometheus workspace ARN"
  type        = string
}

variable "amp_remote_write_endpoint" {
  description = "Amazon Managed Prometheus remote write endpoint URL"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name for ADOT logs"
  type        = string
}

variable "app_port" {
  description = "Application port for Prometheus metrics scraping"
  type        = number
  default     = 8080
}

variable "cluster_name" {
  description = "ECS cluster name for resource tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
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

variable "config_version" {
  description = "Config version for cache busting (e.g., v1, v2, 20251128)"
  type        = string
  default     = ""
}

variable "use_s3_direct" {
  description = "Use S3 direct URL instead of CDN to avoid cache issues"
  type        = bool
  default     = true
}
