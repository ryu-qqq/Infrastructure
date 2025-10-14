# ADOT Collector ECS Integration
# Example integration for adding ADOT Collector as sidecar to ECS tasks
# This file contains reference configurations that should be adapted
# to your specific ECS service definitions

# ============================================================================
# ADOT Collector Configuration as SSM Parameter
# ============================================================================

# Store ADOT configuration in SSM Parameter Store
resource "aws_ssm_parameter" "adot-config" {
  name        = "/${var.environment}/monitoring/adot-config"
  description = "ADOT Collector configuration for ECS tasks"
  type        = "String"
  value       = file("${path.module}/configs/adot-config.yaml")

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-adot-config"
      Component   = "adot"
      Description = "ADOT Collector configuration"
    }
  )
}

# ============================================================================
# CloudWatch Log Group for ADOT Collector
# ============================================================================

resource "aws_cloudwatch_log_group" "adot-collector" {
  name              = "/aws/ecs/adot-collector"
  retention_in_days = 7
  kms_key_id        = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-adot-collector-logs"
      Component   = "adot"
      Description = "ADOT Collector container logs"
    }
  )
}

# ============================================================================
# Example: ADOT Collector Container Definition
# ============================================================================

# This is an example container definition for ADOT Collector
# Add this as a sidecar to your ECS task definition

locals {
  adot_collector_container_definition = {
    name  = "adot-collector"
    image = "public.ecr.aws/aws-observability/aws-otel-collector:${var.adot_image_version}"

    essential = true

    # Resource limits
    cpu    = 256
    memory = 512

    # Environment variables
    environment = [
      {
        name  = "AWS_REGION"
        value = var.aws_region
      },
      {
        name  = "AMP_ENDPOINT"
        value = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
      },
      {
        name  = "SERVICE_NAME"
        value = "atlantis" # Change per service
      }
    ]

    # Secrets (if needed)
    secrets = []

    # Configuration via SSM Parameter
    command = [
      "--config=/etc/ecs/ecs-adot-config.yaml"
    ]

    # Port mappings for health checks and debugging
    portMappings = [
      {
        containerPort = 13133 # Health check
        protocol      = "tcp"
      },
      {
        containerPort = 8888 # Prometheus metrics
        protocol      = "tcp"
      },
      {
        containerPort = 55679 # zPages
        protocol      = "tcp"
      }
    ]

    # Health check
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:13133/ || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    # Logging configuration
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.adot-collector.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "adot"
      }
    }

    # Depends on the application container
    dependsOn = []
  }

  # Output as JSON string for use in task definitions
  adot_collector_json = jsonencode(local.adot_collector_container_definition)
}

# ============================================================================
# Example: Updated Task Definition with ADOT Collector
# ============================================================================

# Example of how to integrate ADOT into an existing task definition
# This is a reference - adapt to your actual task definition file

/*
resource "aws_ecs_task_definition" "example-with-adot" {
  family                   = "example-service-with-monitoring"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 768  # 512 (app) + 256 (adot)
  memory                   = 1536 # 1024 (app) + 512 (adot)

  # Use the ECS task role with AMP write permissions
  task_role_arn      = aws_iam_role.ecs-amp-writer.arn
  execution_role_arn = aws_iam_role.ecs-task-execution.arn  # Your existing execution role

  container_definitions = jsonencode([
    {
      # Your application container
      name      = "app"
      image     = "your-app-image:latest"
      essential = true
      cpu       = 512
      memory    = 1024

      portMappings = [{
        containerPort = 8080
        protocol      = "tcp"
      }]

      # Expose Prometheus metrics on /metrics endpoint
      environment = [
        { name = "METRICS_PORT", value = "8080" },
        { name = "METRICS_PATH", value = "/metrics" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/aws/ecs/your-service"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    },

    # ADOT Collector sidecar
    local.adot_collector_container_definition
  ])

  tags = merge(
    local.required_tags,
    {
      Name        = "example-service-with-monitoring"
      Component   = "ecs"
      Description = "Example ECS task definition with ADOT monitoring"
    }
  )
}
*/

# ============================================================================
# Data Sources
# ============================================================================

# If you need to reference existing ECS task execution role
# data "aws_iam_role" "ecs_task_execution" {
#   name = "ecsTaskExecutionRole"
# }
