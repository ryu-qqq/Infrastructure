# CloudWatch Log Group for Container Logs
resource "aws_cloudwatch_log_group" "this" {
  count = var.log_configuration == null ? 1 : 0

  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name        = "/ecs/${var.name}"
      Description = "CloudWatch log group for ECS service ${var.name}"
    }
  )
}

# ECS Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = var.container_environment
      secrets     = var.container_secrets

      # Health check configuration (if provided)
      healthCheck = var.health_check_command != null ? {
        command     = var.health_check_command
        interval    = var.health_check_interval
        timeout     = var.health_check_timeout
        retries     = var.health_check_retries
        startPeriod = var.health_check_start_period
      } : null

      # Log configuration
      logConfiguration = var.log_configuration != null ? {
        logDriver = var.log_configuration.log_driver
        options   = var.log_configuration.options
        } : {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this[0].name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = var.container_name
        }
      }
    }
  ])

  tags = merge(
    var.common_tags,
    {
      Name        = var.name
      Description = "ECS task definition for ${var.name}"
    }
  )
}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Network configuration
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  # Load balancer configuration (if provided)
  dynamic "load_balancer" {
    for_each = var.load_balancer_config != null ? [var.load_balancer_config] : []
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  # Deployment configuration
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent

  # Deployment circuit breaker
  deployment_circuit_breaker {
    enable   = var.deployment_circuit_breaker_enable
    rollback = var.deployment_circuit_breaker_rollback
  }

  # Health check grace period (required when using load balancer)
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  # Enable ECS managed tags
  enable_ecs_managed_tags = var.enable_ecs_managed_tags
  propagate_tags          = var.propagate_tags

  # Enable ECS Exec
  enable_execute_command = var.enable_execute_command

  tags = merge(
    var.common_tags,
    {
      Name        = var.name
      Description = "ECS service for ${var.name}"
    }
  )
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "this" {
  count = var.enable_autoscaling ? 1 : 0

  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${element(split("/", var.cluster_id), length(split("/", var.cluster_id)) - 1)}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    precondition {
      condition     = var.autoscaling_max_capacity >= var.autoscaling_min_capacity
      error_message = "Auto scaling max_capacity (${var.autoscaling_max_capacity}) must be greater than or equal to min_capacity (${var.autoscaling_min_capacity})"
    }
  }
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "cpu" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${var.name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.autoscaling_target_cpu

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "memory" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${var.name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.autoscaling_target_memory

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
