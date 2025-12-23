# ECS Task Definition for n8n

resource "aws_ecs_task_definition" "n8n" {
  family                   = local.name_prefix
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.n8n_cpu
  memory                   = var.n8n_memory
  execution_role_arn       = module.n8n_task_execution_role.role_arn
  task_role_arn            = module.n8n_task_role.role_arn

  container_definitions = jsonencode([
    {
      name      = local.n8n_container_name
      image     = "n8nio/n8n:${var.n8n_image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = local.n8n_container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        # Database Configuration
        {
          name  = "DB_TYPE"
          value = "postgresdb"
        },
        {
          name  = "DB_POSTGRESDB_HOST"
          value = module.n8n_rds.db_instance_address
        },
        {
          name  = "DB_POSTGRESDB_PORT"
          value = tostring(local.db_port)
        },
        {
          name  = "DB_POSTGRESDB_DATABASE"
          value = local.db_name
        },
        {
          name  = "DB_POSTGRESDB_USER"
          value = local.db_username
        },
        {
          name  = "DB_POSTGRESDB_SSL_ENABLED"
          value = "true"
        },
        {
          name  = "DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED"
          value = "false"
        },
        # n8n Configuration
        {
          name  = "N8N_HOST"
          value = replace(var.n8n_url, "https://", "")
        },
        {
          name  = "N8N_PORT"
          value = tostring(local.n8n_container_port)
        },
        {
          name  = "N8N_PROTOCOL"
          value = "https"
        },
        {
          name  = "WEBHOOK_URL"
          value = var.n8n_webhook_url != "" ? var.n8n_webhook_url : var.n8n_url
        },
        {
          name  = "GENERIC_TIMEZONE"
          value = var.n8n_timezone
        },
        # Execution Settings
        {
          name  = "EXECUTIONS_MODE"
          value = "regular"
        },
        {
          name  = "EXECUTIONS_DATA_SAVE_ON_ERROR"
          value = "all"
        },
        {
          name  = "EXECUTIONS_DATA_SAVE_ON_SUCCESS"
          value = "all"
        },
        {
          name  = "EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS"
          value = "true"
        },
        # Security Settings
        {
          name  = "N8N_PERSONALIZATION_ENABLED"
          value = "false"
        },
        {
          name  = "N8N_DIAGNOSTICS_ENABLED"
          value = "false"
        },
        {
          name  = "N8N_VERSION_NOTIFICATIONS_ENABLED"
          value = "false"
        },
        # AuthHub Integration
        {
          name  = "AUTHHUB_API_URL"
          value = "https://api.set-of.com"
        }
      ]

      # Secrets from Secrets Manager
      secrets = [
        {
          name      = "DB_POSTGRESDB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.n8n-db-password.arn}:password::"
        },
        {
          name      = "N8N_ENCRYPTION_KEY"
          valueFrom = "${aws_secretsmanager_secret.n8n-encryption-key.arn}:encryption_key::"
        },
        # AuthHub Service Token
        {
          name      = "SERVICE_TOKEN_SECRET"
          valueFrom = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/authhub/security/service-token-secret"
        }
      ]

      # Health check configuration
      healthCheck = {
        command = [
          "CMD-SHELL",
          "wget -q --spider http://localhost:${local.n8n_container_port}/healthz || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = module.n8n_logs.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "n8n"
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
      Name        = local.name_prefix
      Description = "ECS task definition for n8n workflow automation"
    }
  )
}

# Outputs
output "task_definition_arn" {
  description = "The ARN of the n8n task definition"
  value       = aws_ecs_task_definition.n8n.arn
}

output "task_definition_family" {
  description = "The family of the n8n task definition"
  value       = aws_ecs_task_definition.n8n.family
}
