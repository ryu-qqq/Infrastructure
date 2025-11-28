# ========================================
# ADOT Sidecar Module
# ========================================
# AWS Distro for OpenTelemetry sidecar container
# for collecting metrics to Amazon Managed Prometheus
# and traces to AWS X-Ray via OTLP
# ========================================

# ========================================
# Local Variables
# ========================================
locals {
  adot_container_name = "adot-collector"
  adot_image          = "public.ecr.aws/aws-observability/aws-otel-collector:latest"

  # S3 direct URL (bypasses CDN cache)
  # ADOT requires format: s3://bucket.s3.region.amazonaws.com/path
  s3_config_url = "s3://${var.config_bucket}.s3.${var.aws_region}.amazonaws.com/otel-config/${var.project_name}-${var.service_name}/otel-config.yaml"

  # CDN URL with optional cache-busting query parameter (fallback)
  base_cdn_url  = "https://${var.cdn_host}/otel-config/${var.project_name}-${var.service_name}/otel-config.yaml"
  cdn_config_url = var.config_version != "" ? "${local.base_cdn_url}?v=${var.config_version}" : local.base_cdn_url

  # Use S3 direct by default to avoid CDN cache issues
  otel_config_url = var.use_s3_direct ? local.s3_config_url : local.cdn_config_url
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

    # OTLP receiver ports for metrics and traces
    portMappings = [
      {
        containerPort = 4317
        protocol      = "tcp"
        # OTLP gRPC endpoint
      },
      {
        containerPort = 4318
        protocol      = "tcp"
        # OTLP HTTP endpoint
      }
    ]

    # Environment variables for ADOT collector config
    environment = [
      {
        name  = "AWS_REGION"
        value = var.aws_region
      },
      {
        name  = "AMP_ENDPOINT"
        value = var.amp_remote_write_endpoint
      },
      {
        name  = "SERVICE_NAME"
        value = "${var.project_name}-${var.service_name}"
      },
      {
        name  = "APP_PORT"
        value = tostring(var.app_port)
      },
      {
        name  = "CLUSTER_NAME"
        value = var.cluster_name
      },
      {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    ]

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
# Required permissions for ADOT to write to AMP and X-Ray
output "iam_policy_document" {
  description = "IAM policy document for ADOT to access AMP and X-Ray"
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
        Sid    = "XRayTracing"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
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
