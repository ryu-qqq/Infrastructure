# Variables for Service Discovery

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "namespace_name" {
  description = "Cloud Map namespace name (private DNS)"
  type        = string
  default     = "connectly.local"
}

variable "namespace_description" {
  description = "Description for the Cloud Map namespace"
  type        = string
  default     = "Service Discovery namespace for internal service communication"
}

# --- Tagging Variables ---

variable "team" {
  description = "Team responsible for the resource"
  type        = string
  default     = "platform-team"
}

variable "owner" {
  description = "Owner of the resource"
  type        = string
  default     = "platform@ryuqqq.com"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "platform"
}

variable "service_name" {
  description = "Service name"
  type        = string
  default     = "service-discovery"
}

variable "lifecycle_stage" {
  description = "Lifecycle stage"
  type        = string
  default     = "production"
}

variable "data_class" {
  description = "Data classification"
  type        = string
  default     = "internal"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "infrastructure"
}
