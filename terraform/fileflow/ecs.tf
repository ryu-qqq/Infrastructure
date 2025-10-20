# ============================================================================
# ECS Configuration
# ============================================================================

# ECS Cluster
resource "aws_ecs_cluster" "fileflow" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-cluster"
      Component = "ecs"
    }
  )
}

# CloudWatch Log Group for ECS Exec
resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/${local.service_name}/exec"
  retention_in_days = 7
  kms_key_id        = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-exec-logs"
      Component = "logging"
    }
  )
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/${local.service_name}/application"
  retention_in_days = 14
  kms_key_id        = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-app-logs"
      Component = "logging"
    }
  )
}

# Security group for ECS tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${local.name_prefix}-ecs-tasks-"
  description = "Security group for fileflow ECS tasks"
  vpc_id      = var.vpc_id

  # Allow inbound from ALB
  ingress {
    from_port       = var.ecs_container_port
    to_port         = var.ecs_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow traffic from ALB"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-tasks"
      Component = "ecs"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Update Redis security group to allow ECS tasks
resource "aws_security_group_rule" "redis_from_ecs_tasks" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = module.redis.security_group_id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "Allow Redis access from ECS tasks"
}

# ECS Service
module "ecs_service" {
  source = "../modules/ecs-service"

  # Service configuration
  name               = local.service_name
  cluster_id         = aws_ecs_cluster.fileflow.id
  container_name     = local.service_name
  container_image    = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.service_name}:latest"
  container_port     = var.ecs_container_port
  cpu                = var.ecs_task_cpu
  memory             = var.ecs_task_memory
  desired_count      = var.ecs_desired_count

  # Network configuration
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [
    aws_security_group.ecs_tasks.id,
    aws_security_group.redis_client.id
  ]
  assign_public_ip   = false

  # IAM roles
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  # ALB integration
  enable_load_balancer = true
  target_group_arn     = module.alb.target_group_arns["fileflow"]

  # Environment variables
  container_environment = [
    {
      name  = "SPRING_PROFILES_ACTIVE"
      value = var.environment
    },
    {
      name  = "SERVER_PORT"
      value = tostring(var.ecs_container_port)
    },
    {
      name  = "AWS_REGION"
      value = var.aws_region
    },
    {
      name  = "REDIS_HOST"
      value = module.redis.endpoint
    },
    {
      name  = "REDIS_PORT"
      value = "6379"
    },
    {
      name  = "S3_BUCKET_NAME"
      value = module.fileflow_bucket.bucket_id
    },
    {
      name  = "SQS_FILE_PROCESSING_QUEUE_URL"
      value = module.file_processing_queue.queue_url
    },
    {
      name  = "SQS_FILE_UPLOAD_QUEUE_URL"
      value = module.file_upload_queue.queue_url
    },
    {
      name  = "SQS_FILE_COMPLETION_QUEUE_URL"
      value = module.file_completion_queue.queue_url
    },
    {
      name  = "DB_HOST"
      value = data.terraform_remote_state.rds.outputs.endpoint
    },
    {
      name  = "DB_PORT"
      value = "3306"
    },
    {
      name  = "DB_NAME"
      value = var.db_name
    }
  ]

  # Secrets from Secrets Manager
  container_secrets = [
    {
      name      = "DB_USERNAME"
      valueFrom = "${data.terraform_remote_state.rds.outputs.master_user_secret_arn}:username::"
    },
    {
      name      = "DB_PASSWORD"
      valueFrom = "${data.terraform_remote_state.rds.outputs.master_user_secret_arn}:password::"
    },
    {
      name      = "REDIS_AUTH_TOKEN"
      valueFrom = "${module.redis.auth_token_secret_arn}::"  # Assuming ElastiCache module outputs this
    }
  ]

  # Health check
  health_check_command = [
    "CMD-SHELL",
    "curl -f http://localhost:${var.ecs_container_port}/actuator/health || exit 1"
  ]
  health_check_interval    = 30
  health_check_timeout     = 5
  health_check_retries     = 3
  health_check_start_period = 60

  # Logging
  log_group_name              = aws_cloudwatch_log_group.app.name
  log_stream_prefix           = "ecs"
  enable_cloudwatch_log_group = false  # Already created above

  # Deployment configuration
  enable_deployment_circuit_breaker = true
  enable_rollback                   = true
  deployment_maximum_percent        = 200
  deployment_minimum_healthy_percent = 100

  # ECS Exec (for debugging)
  enable_ecs_exec = var.environment != "prod"

  # Auto Scaling
  enable_autoscaling            = true
  autoscaling_min_capacity      = var.environment == "prod" ? 2 : 1
  autoscaling_max_capacity      = var.environment == "prod" ? 10 : 3
  autoscaling_cpu_target        = 70
  autoscaling_memory_target     = 80
  autoscaling_scale_in_cooldown = 300
  autoscaling_scale_out_cooldown = 60

  # Tags
  common_tags = local.required_tags
}

# CloudWatch Alarms for ECS Service
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${local.name_prefix}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS service CPU utilization is too high"
  alarm_actions       = [data.terraform_remote_state.monitoring.outputs.alerts_topic_arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.fileflow.name
    ServiceName = module.ecs_service.service_name
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-cpu-high"
      Component = "monitoring"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${local.name_prefix}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "ECS service memory utilization is too high"
  alarm_actions       = [data.terraform_remote_state.monitoring.outputs.alerts_topic_arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.fileflow.name
    ServiceName = module.ecs_service.service_name
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-memory-high"
      Component = "monitoring"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "ecs_task_count_low" {
  alarm_name          = "${local.name_prefix}-ecs-task-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "ECS service has no running tasks"
  alarm_actions       = [data.terraform_remote_state.monitoring.outputs.alerts_topic_arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.fileflow.name
    ServiceName = module.ecs_service.service_name
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-task-count-low"
      Component = "monitoring"
    }
  )
}
