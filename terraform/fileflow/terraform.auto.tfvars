# Fileflow Terraform Configuration Variables
# This file is auto-loaded by Terraform and committed to git
# Only non-sensitive values should be included here

# ============================================================================
# General Configuration
# ============================================================================

environment = "prod"
aws_region  = "ap-northeast-2"

# ============================================================================
# Network Configuration
# ============================================================================

vpc_id = "vpc-0f162b9e588276e09" # prod-server-vpc (shared with other services)

# ============================================================================
# Tags Configuration
# ============================================================================

tags_owner       = "platform-team@ryuqqq.com"
tags_cost_center = "engineering"
tags_team        = "platform-team"

# ============================================================================
# Redis (ElastiCache) Configuration
# ============================================================================

redis_node_type        = "cache.t4g.micro"
redis_num_cache_nodes  = 1
redis_engine_version   = "7.1"

# ============================================================================
# S3 Configuration
# ============================================================================

s3_versioning_enabled      = true
s3_lifecycle_glacier_days  = 90

# ============================================================================
# SQS Configuration
# ============================================================================

sqs_visibility_timeout_seconds = 300     # 5 minutes
sqs_message_retention_seconds  = 1209600 # 14 days
sqs_receive_wait_time_seconds  = 20      # Long polling

# ============================================================================
# ECS Configuration
# ============================================================================

# ECS Cluster
ecs_cluster_name = "" # Empty string means new cluster will be created

# Task Configuration
ecs_task_cpu    = "512"  # 0.5 vCPU
ecs_task_memory = "1024" # 1 GB

# Service Configuration
ecs_desired_count  = 2     # Start with 2 tasks for high availability
ecs_container_port = 8080  # Spring Boot default port

# ============================================================================
# ALB Configuration
# ============================================================================

alb_internal            = false # Public-facing ALB
alb_health_check_path   = "/actuator/health"
alb_health_check_interval = 30 # seconds

# ============================================================================
# Database Configuration
# ============================================================================

db_name     = "fileflow"
db_username = "fileflow_user"

# ============================================================================
# Additional Tags
# ============================================================================

tags = {
  Application = "fileflow"
  Stack       = "fileflow"
  ManagedBy   = "Terraform"
  Repository  = "github.com/ryu-qqq/infrastructure"
}

# ============================================================================
# Notes
# ============================================================================

# Last Updated: 2025-10-20
#
# Infrastructure Stack:
# - ECS Fargate for container orchestration
# - ALB for load balancing
# - Redis (ElastiCache) for caching
# - S3 for file storage
# - SQS for async message processing
# - RDS MySQL for database (shared resource)
# - Secrets Manager for credential management
#
# Shared Resources (from other modules):
# - VPC and Subnets (network)
# - RDS MySQL Instance (rds)
# - KMS Keys (kms)
# - CloudWatch Alarms and SNS Topics (monitoring)
