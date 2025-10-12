# ECS Service for Atlantis

resource "aws_ecs_service" "atlantis" {
  name            = "atlantis-${var.environment}"
  cluster         = aws_ecs_cluster.atlantis.id
  task_definition = aws_ecs_task_definition.atlantis.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Network configuration
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.atlantis-ecs-tasks.id]
    assign_public_ip = false
  }

  # Load balancer configuration
  load_balancer {
    target_group_arn = aws_lb_target_group.atlantis.arn
    container_name   = "atlantis"
    container_port   = var.atlantis_container_port
  }

  # Deployment configuration - Blue/Green strategy
  # deployment_maximum_percent = 100: Only 1 task can run at a time
  # deployment_minimum_healthy_percent = 0: Old task stops before new task starts
  # This prevents concurrent access to EFS Atlantis data directory
  deployment_maximum_percent         = 100 # Only one task at a time
  deployment_minimum_healthy_percent = 0   # Stop old before starting new

  # Deployment circuit breaker for automatic rollback
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Health check grace period for ALB health checks
  health_check_grace_period_seconds = 60

  # Enable ECS managed tags
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-${var.environment}"
      Component   = "atlantis"
      Description = "ECS service for Atlantis Terraform automation server"
    }
  )

  # Ensure service is created after target group is ready
  depends_on = [
    aws_lb_listener.atlantis-https,
    aws_lb_listener.atlantis-http
  ]
}

# Outputs
output "atlantis_ecs_service_name" {
  description = "The name of the Atlantis ECS service"
  value       = aws_ecs_service.atlantis.name
}

output "atlantis_ecs_service_id" {
  description = "The ID of the Atlantis ECS service"
  value       = aws_ecs_service.atlantis.id
}
