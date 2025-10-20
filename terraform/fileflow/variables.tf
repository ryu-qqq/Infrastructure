# ============================================================================
# General Configuration
# ============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name (prod, staging, dev)"
  type        = string
  default     = "prod"
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "vpc_id" {
  description = "VPC ID (shared infrastructure)"
  type        = string
}

# ============================================================================
# Tags
# ============================================================================

variable "tags_owner" {
  description = "Owner email for resource tagging"
  type        = string
  default     = "platform-team@ryuqqq.com"
}

variable "tags_cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

variable "tags_team" {
  description = "Team name"
  type        = string
  default     = "platform-team"
}

# ============================================================================
# Redis (ElastiCache) Configuration
# ============================================================================

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

# ============================================================================
# S3 Configuration
# ============================================================================

variable "s3_versioning_enabled" {
  description = "Enable S3 versioning"
  type        = bool
  default     = true
}

variable "s3_lifecycle_glacier_days" {
  description = "Days before transitioning to Glacier"
  type        = number
  default     = 90
}

# ============================================================================
# SQS Configuration
# ============================================================================

variable "sqs_visibility_timeout_seconds" {
  description = "SQS visibility timeout"
  type        = number
  default     = 300
}

variable "sqs_message_retention_seconds" {
  description = "SQS message retention period"
  type        = number
  default     = 1209600 # 14 days
}

variable "sqs_receive_wait_time_seconds" {
  description = "SQS long polling wait time"
  type        = number
  default     = 20
}

# ============================================================================
# ECS Configuration
# ============================================================================

variable "ecs_cluster_name" {
  description = "ECS cluster name (if using existing cluster)"
  type        = string
  default     = ""
}

variable "ecs_task_cpu" {
  description = "ECS task CPU units"
  type        = string
  default     = "512"
}

variable "ecs_task_memory" {
  description = "ECS task memory (MiB)"
  type        = string
  default     = "1024"
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_container_port" {
  description = "Container port for the application"
  type        = number
  default     = 8080
}

# ============================================================================
# ALB Configuration
# ============================================================================

variable "alb_internal" {
  description = "Whether ALB is internal"
  type        = bool
  default     = false
}

variable "alb_health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/actuator/health"
}

variable "alb_health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

# ============================================================================
# Database Configuration
# ============================================================================

variable "db_name" {
  description = "Database name for fileflow"
  type        = string
  default     = "fileflow"
}

variable "db_username" {
  description = "Database username for fileflow"
  type        = string
  default     = "fileflow_user"
}

# ============================================================================
# Additional Tags
# ============================================================================

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
