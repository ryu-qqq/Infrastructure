# ECS Service for n8n

resource "aws_ecs_service" "n8n" {
  name            = local.name_prefix
  cluster         = aws_ecs_cluster.n8n.id
  task_definition = aws_ecs_task_definition.n8n.arn
  desired_count   = var.n8n_desired_count
  launch_type     = "FARGATE"

  # Network configuration
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [module.n8n_ecs_tasks_sg.security_group_id]
    assign_public_ip = false
  }

  # Load balancer configuration
  load_balancer {
    target_group_arn = module.n8n_alb.target_group_arns["n8n"]
    container_name   = local.n8n_container_name
    container_port   = local.n8n_container_port
  }

  # Deployment configuration
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  # Deployment circuit breaker for automatic rollback
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Health check grace period
  health_check_grace_period_seconds = 120

  # Enable ECS managed tags
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  tags = merge(
    local.required_tags,
    {
      Name        = local.name_prefix
      Description = "ECS service for n8n workflow automation"
    }
  )

  # Ensure service is created after dependencies are ready
  depends_on = [
    module.n8n_alb,
    module.n8n_rds
  ]
}

# Outputs
output "ecs_service_name" {
  description = "The name of the n8n ECS service"
  value       = aws_ecs_service.n8n.name
}

output "ecs_service_id" {
  description = "The ID of the n8n ECS service"
  value       = aws_ecs_service.n8n.id
}
