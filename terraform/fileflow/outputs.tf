# ============================================================================
# Outputs
# ============================================================================

# ============================================================================
# Network Outputs
# ============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = var.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = data.aws_subnets.private.ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = data.aws_subnets.public.ids
}

# ============================================================================
# ALB Outputs
# ============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.arn
}

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

# ============================================================================
# ECS Outputs
# ============================================================================

output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.fileflow.id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.fileflow.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.fileflow.arn
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs_service.service_name
}

output "ecs_service_arn" {
  description = "ECS service ARN"
  value       = module.ecs_service.service_arn
}

output "ecs_task_definition_arn" {
  description = "ECS task definition ARN"
  value       = module.ecs_service.task_definition_arn
}

output "ecs_task_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task_role.arn
}

output "ecs_execution_role_arn" {
  description = "ECS execution role ARN"
  value       = aws_iam_role.ecs_execution_role.arn
}

# ============================================================================
# Redis Outputs
# ============================================================================

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.redis.endpoint
}

output "redis_port" {
  description = "Redis port"
  value       = 6379
}

output "redis_security_group_id" {
  description = "Redis security group ID"
  value       = module.redis.security_group_id
}

# ============================================================================
# S3 Outputs
# ============================================================================

output "s3_bucket_id" {
  description = "S3 bucket ID (name)"
  value       = module.fileflow_bucket.bucket_id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.fileflow_bucket.bucket_arn
}

output "s3_bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = module.fileflow_bucket.bucket_domain_name
}

output "s3_logs_bucket_id" {
  description = "S3 logs bucket ID (name)"
  value       = module.fileflow_logs_bucket.bucket_id
}

output "s3_logs_bucket_arn" {
  description = "S3 logs bucket ARN"
  value       = module.fileflow_logs_bucket.bucket_arn
}

# ============================================================================
# SQS Outputs
# ============================================================================

output "file_processing_queue_url" {
  description = "File processing queue URL"
  value       = module.file_processing_queue.queue_url
}

output "file_processing_queue_arn" {
  description = "File processing queue ARN"
  value       = module.file_processing_queue.queue_arn
}

output "file_upload_queue_url" {
  description = "File upload queue URL"
  value       = module.file_upload_queue.queue_url
}

output "file_upload_queue_arn" {
  description = "File upload queue ARN"
  value       = module.file_upload_queue.queue_arn
}

output "file_completion_queue_url" {
  description = "File completion queue URL"
  value       = module.file_completion_queue.queue_url
}

output "file_completion_queue_arn" {
  description = "File completion queue ARN"
  value       = module.file_completion_queue.queue_arn
}

# ============================================================================
# Database Outputs
# ============================================================================

output "db_name" {
  description = "Database name"
  value       = var.db_name
}

output "db_username" {
  description = "Database username"
  value       = var.db_username
  sensitive   = true
}

output "db_credentials_secret_arn" {
  description = "ARN of Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.fileflow_db_credentials.arn
}

output "db_host" {
  description = "Database host endpoint"
  value       = data.terraform_remote_state.rds.outputs.endpoint
}

# ============================================================================
# CloudWatch Logs Outputs
# ============================================================================

output "app_log_group_name" {
  description = "CloudWatch Log Group name for application logs"
  value       = aws_cloudwatch_log_group.app.name
}

output "app_log_group_arn" {
  description = "CloudWatch Log Group ARN for application logs"
  value       = aws_cloudwatch_log_group.app.arn
}

output "ecs_exec_log_group_name" {
  description = "CloudWatch Log Group name for ECS Exec"
  value       = aws_cloudwatch_log_group.ecs_exec.name
}

# ============================================================================
# Application Configuration
# ============================================================================

output "application_url" {
  description = "Application URL (ALB DNS)"
  value       = "https://${module.alb.dns_name}"
}

output "service_name" {
  description = "Service name"
  value       = local.service_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# ============================================================================
# Summary Output
# ============================================================================

output "deployment_summary" {
  description = "Deployment summary information"
  value = {
    service          = local.service_name
    environment      = var.environment
    region           = var.aws_region
    ecs_cluster      = aws_ecs_cluster.fileflow.name
    ecs_service      = module.ecs_service.service_name
    alb_dns          = module.alb.dns_name
    s3_bucket        = module.fileflow_bucket.bucket_id
    redis_endpoint   = module.redis.endpoint
    db_name          = var.db_name
    db_secret_arn    = aws_secretsmanager_secret.fileflow_db_credentials.arn
  }
}
