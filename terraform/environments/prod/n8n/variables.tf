# Variables for n8n Terraform Configuration

# =============================================================================
# Environment Configuration
# =============================================================================

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

# =============================================================================
# Required Tags (Governance Standard)
# =============================================================================

variable "service_name" {
  description = "Service name this resource belongs to"
  type        = string
  default     = "n8n"
}

variable "team" {
  description = "Team responsible for the resource"
  type        = string
  default     = "platform-team"
}

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

variable "data_class" {
  description = "Data classification (public, internal, confidential, restricted)"
  type        = string
  default     = "confidential"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "vpc_id" {
  description = "VPC ID where n8n will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB deployment"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks and RDS"
  type        = list(string)
}

# =============================================================================
# ECS Task Configuration
# =============================================================================

variable "n8n_cpu" {
  description = "CPU units for the n8n task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 1024
}

variable "n8n_memory" {
  description = "Memory (MiB) for the n8n task"
  type        = number
  default     = 2048
}

variable "n8n_image_tag" {
  description = "n8n Docker image tag"
  type        = string
  default     = "latest"
}

variable "n8n_desired_count" {
  description = "Number of n8n tasks to run"
  type        = number
  default     = 1
}

# =============================================================================
# n8n Application Configuration
# =============================================================================

variable "n8n_url" {
  description = "The URL that n8n will be accessible at (e.g., https://n8n.example.com)"
  type        = string
}

variable "n8n_webhook_url" {
  description = "The webhook URL for n8n (usually same as n8n_url)"
  type        = string
  default     = ""
}

variable "n8n_timezone" {
  description = "Timezone for n8n"
  type        = string
  default     = "Asia/Seoul"
}

variable "n8n_encryption_key" {
  description = "Encryption key for n8n credentials (32+ characters)"
  type        = string
  sensitive   = true
}

# =============================================================================
# RDS Configuration
# =============================================================================

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for RDS autoscaling (GB)"
  type        = number
  default     = 100
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

# =============================================================================
# ALB Configuration
# =============================================================================

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS listener"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/healthz"
}

variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

# =============================================================================
# Route53 Configuration (Optional)
# =============================================================================

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS record"
  type        = string
  default     = ""
}

variable "route53_record_name" {
  description = "DNS record name (e.g., n8n.example.com)"
  type        = string
  default     = ""
}
