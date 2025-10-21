# FileFlow Infrastructure Outputs

# ============================================================================
# ECS Cluster Outputs
# ============================================================================

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

# ============================================================================
# ECS Service Outputs
# ============================================================================

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.fileflow.name
}

output "ecs_service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.fileflow.id
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.fileflow.arn
}

# ============================================================================
# Load Balancer Outputs
# ============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.fileflow.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.fileflow.arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.fileflow.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.fileflow.arn
}

# ============================================================================
# Security Group Outputs
# ============================================================================

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs-tasks.id
}

# ============================================================================
# IAM Role Outputs
# ============================================================================

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs-task-execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs-task.arn
}

# ============================================================================
# Secrets Manager Outputs
# ============================================================================

output "database_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.fileflow-db.arn
}

output "database_secret_name" {
  description = "Name of the database credentials secret"
  value       = aws_secretsmanager_secret.fileflow-db.name
}

# ============================================================================
# CloudWatch Outputs
# ============================================================================

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.fileflow.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.fileflow.arn
}

# ============================================================================
# Service URL
# ============================================================================

output "service_url" {
  description = "URL to access the FileFlow service"
  value       = "http://${aws_lb.fileflow.dns_name}"
}

output "health_check_url" {
  description = "Health check endpoint URL"
  value       = "http://${aws_lb.fileflow.dns_name}${var.health_check_path}"
}
