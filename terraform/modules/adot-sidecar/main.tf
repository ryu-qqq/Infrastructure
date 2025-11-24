# ========================================
# ADOT Sidecar Module
# ========================================
# AWS Distro for OpenTelemetry sidecar container
# for collecting metrics to Amazon Managed Prometheus
# ========================================

# ========================================
# Local Variables
# ========================================
locals {
  adot_container_name = "adot-collector"
  adot_image          = "public.ecr.aws/aws-observability/aws-otel-collector:latest"

  # OTEL config URL pattern
  otel_config_url = "https://${var.cdn_host}/otel-config/${var.project_name}-${var.service_name}/otel-config.yaml"
}

# ========================================
# ADOT Container Definition
# ========================================
# This output can be merged with your main container definitions
output "container_definition" {
  description = "ADOT sidecar container definition to add to ECS task"
  value = {
    name      = local.adot_container_name
    image     = local.adot_image
    cpu       = var.adot_cpu
    memory    = var.adot_memory
    essential = false

    command = [
      "--config=${local.otel_config_url}"
    ]

    environment = []

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "adot"
      }
    }
  }
}

# ========================================
# IAM Policy for ADOT
# ========================================
# Required permissions for ADOT to write to AMP
output "iam_policy_document" {
  description = "IAM policy document for ADOT to access AMP"
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AMPRemoteWrite"
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite"
        ]
        Resource = var.amp_workspace_arn
      },
      {
        Sid    = "S3ConfigAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::${var.config_bucket}/*"
      }
    ]
  })
}

# ========================================
# Output: Config URL
# ========================================
output "otel_config_url" {
  description = "URL where OTEL config should be placed"
  value       = local.otel_config_url
}
