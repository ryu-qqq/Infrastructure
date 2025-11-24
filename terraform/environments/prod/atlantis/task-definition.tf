# ECS Task Definition for Atlantis
# Note: ECS task definition kept as raw resource due to complex EFS volume configuration

resource "aws_ecs_task_definition" "atlantis" {
  family                   = "atlantis-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.atlantis_cpu
  memory                   = var.atlantis_memory
  execution_role_arn       = module.atlantis_task_execution_role.role_arn
  task_role_arn            = module.atlantis_task_role.role_arn

  # EFS Volume for Atlantis data persistence
  volume {
    name = "atlantis-data"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.atlantis.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2049

      authorization_config {
        access_point_id = aws_efs_access_point.atlantis.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "atlantis"
      image     = "${module.atlantis_ecr.repository_url}:${var.atlantis_version}"
      essential = true

      portMappings = [
        {
          containerPort = var.atlantis_container_port
          protocol      = "tcp"
        }
      ]

      # Mount EFS volume to Atlantis data directory
      mountPoints = [
        {
          sourceVolume  = "atlantis-data"
          containerPath = "/home/atlantis/.atlantis"
          readOnly      = false
        }
      ]

      environment = [
        {
          name  = "ATLANTIS_PORT"
          value = tostring(var.atlantis_container_port)
        },
        {
          name  = "ATLANTIS_ATLANTIS_URL"
          value = var.atlantis_url
        },
        {
          name  = "ATLANTIS_REPO_ALLOWLIST"
          value = var.atlantis_repo_allowlist
        },
        {
          name  = "ATLANTIS_LOG_LEVEL"
          value = "debug"
        },
        {
          name  = "ATLANTIS_WRITE_GIT_CREDS"
          value = "true"
        },
        {
          name  = "ATLANTIS_REPO_CONFIG"
          value = "/home/atlantis/repos.yaml"
        }
      ]

      # GitHub App credentials from Secrets Manager
      secrets = [
        {
          name      = "ATLANTIS_GH_APP_ID"
          valueFrom = "${aws_secretsmanager_secret.atlantis-github-app.arn}:app_id::"
        },
        {
          name      = "ATLANTIS_GH_APP_INSTALLATION_ID"
          valueFrom = "${aws_secretsmanager_secret.atlantis-github-app.arn}:installation_id::"
        },
        {
          name      = "ATLANTIS_GH_APP_KEY"
          valueFrom = "${aws_secretsmanager_secret.atlantis-github-app.arn}:private_key::"
        },
        {
          name      = "ATLANTIS_GH_WEBHOOK_SECRET"
          valueFrom = "${aws_secretsmanager_secret.atlantis-webhook-secret.arn}:webhook_secret::"
        }
      ]

      # Health check configuration
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.atlantis_container_port}/healthz || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = module.atlantis_logs.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "atlantis"
        }
      }

      # Resource limits
      ulimits = [
        {
          name      = "nofile"
          softLimit = 65536
          hardLimit = 65536
        }
      ]
    }
  ])

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-${var.environment}"
      Component   = "atlantis"
      Description = "ECS task definition for Atlantis Terraform automation server"
    }
  )
}

# Outputs
output "atlantis_task_definition_arn" {
  description = "The ARN of the Atlantis task definition"
  value       = aws_ecs_task_definition.atlantis.arn
}

output "atlantis_task_definition_family" {
  description = "The family of the Atlantis task definition"
  value       = aws_ecs_task_definition.atlantis.family
}

output "atlantis_task_definition_revision" {
  description = "The revision of the Atlantis task definition"
  value       = aws_ecs_task_definition.atlantis.revision
}
