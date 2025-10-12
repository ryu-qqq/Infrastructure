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
  default     = "v0.30.0"
}

# Required Tags (Governance Standard)
variable "owner" {
  description = "Team or individual responsible for the resource"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
}

variable "resource_lifecycle" {
  description = "Resource lifecycle (permanent, temporary, ephemeral)"
  type        = string
  default     = "permanent"
}

variable "data_class" {
  description = "Data classification (public, internal, confidential, restricted)"
  type        = string
  default     = "confidential"
}

variable "service" {
  description = "Service name this resource belongs to"
  type        = string
  default     = "atlantis"
}

# ECS Task Configuration
variable "atlantis_cpu" {
  description = "CPU units for the Atlantis task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "atlantis_memory" {
  description = "Memory (MiB) for the Atlantis task"
  type        = number
  default     = 1024
}

variable "atlantis_container_port" {
  description = "Port the Atlantis container listens on"
  type        = number
  default     = 4141
}

variable "atlantis_repo_allowlist" {
  description = "Allowed repositories for Atlantis webhooks (e.g., github.com/your-org/*)"
  type        = string
  default     = "github.com/ryu-qqq/*"
}

variable "atlantis_url" {
  description = "The URL that Atlantis will be accessible at"
  type        = string
  default     = "https://atlantis.example.com"
}

variable "terraform_state_bucket_prefix" {
  description = "Prefix for Terraform state S3 bucket names"
  type        = string
  default     = "terraform-state"
}

variable "terraform_state_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "terraform-state-lock"
}

# Network Configuration
variable "vpc_id" {
  description = "VPC ID where ALB and ECS will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB deployment"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

# ALB Configuration
variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS listener"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the ALB"
  type        = list(string)
  # No default value - must be explicitly set for security
}

variable "alb_health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/healthz"
}

variable "alb_health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "alb_health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "alb_health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required"
  type        = number
  default     = 2
}

variable "alb_health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required"
  type        = number
  default     = 3
}

variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for ALB (recommended for production environments)"
  type        = bool
  default     = false
}

# GitHub App Configuration
variable "github_app_id" {
  description = "GitHub App ID for Atlantis authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID for Atlantis"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_app_private_key" {
  description = "GitHub App Private Key (PEM format, base64 encoded)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "GitHub Webhook Secret for validating webhook requests"
  type        = string
  default     = ""
  sensitive   = true
}

# Locals for common tags
locals {
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.resource_lifecycle
    DataClass   = var.data_class
    Service     = var.service
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }
}
