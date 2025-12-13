# ==============================================================================
# Primary Identifiers (ID, ARN, Name)
# ==============================================================================

output "service_id" {
  description = "The ID of the ECS service"
  value       = aws_ecs_service.this.id
}

output "service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "The full ARN of the ECS task definition"
  value       = aws_ecs_task_definition.this.arn
}

# ==============================================================================
# Additional Outputs (Alphabetical Order)
# ==============================================================================

output "autoscaling_cpu_policy_arn" {
  description = "The ARN of the CPU auto scaling policy (if auto scaling is enabled)"
  value       = var.enable_autoscaling ? aws_appautoscaling_policy.cpu[0].arn : null
}

output "autoscaling_memory_policy_arn" {
  description = "The ARN of the memory auto scaling policy (if auto scaling is enabled)"
  value       = var.enable_autoscaling ? aws_appautoscaling_policy.memory[0].arn : null
}

output "autoscaling_target_id" {
  description = "The resource ID of the auto scaling target (if auto scaling is enabled)"
  value       = var.enable_autoscaling ? aws_appautoscaling_target.this[0].id : null
}

output "cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch log group (if created by this module)"
  value       = var.log_configuration == null ? aws_cloudwatch_log_group.this[0].arn : null
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group (if created by this module)"
  value       = var.log_configuration == null ? aws_cloudwatch_log_group.this[0].name : null
}

output "container_name" {
  description = "The name of the container"
  value       = var.container_name
}

output "container_port" {
  description = "The port on which the container listens"
  value       = var.container_port
}

output "service_cluster" {
  description = "The cluster in which the service is running"
  value       = aws_ecs_service.this.cluster
}

output "service_desired_count" {
  description = "The desired number of tasks in the service"
  value       = aws_ecs_service.this.desired_count
}

output "task_definition_family" {
  description = "The family of the ECS task definition"
  value       = aws_ecs_task_definition.this.family
}

output "task_definition_revision" {
  description = "The revision number of the ECS task definition"
  value       = aws_ecs_task_definition.this.revision
}

# ==============================================================================
# Service Discovery Outputs
# ==============================================================================

output "service_discovery_service_id" {
  description = "The ID of the Cloud Map service discovery service"
  value       = var.enable_service_discovery ? aws_service_discovery_service.this[0].id : null
}

output "service_discovery_service_arn" {
  description = "The ARN of the Cloud Map service discovery service"
  value       = var.enable_service_discovery ? aws_service_discovery_service.this[0].arn : null
}

output "service_discovery_dns_name" {
  description = "The DNS name for service discovery (e.g., service-name.namespace.local)"
  value       = var.enable_service_discovery ? "${var.name}.${var.service_discovery_namespace_name}" : null
}

output "service_discovery_endpoint" {
  description = "The full endpoint URL for the service (http://dns-name:port)"
  value       = var.enable_service_discovery ? "http://${var.name}.${var.service_discovery_namespace_name}:${var.container_port}" : null
}
