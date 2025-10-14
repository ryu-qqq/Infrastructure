# IAM Roles and Policies for AMP/AMG Monitoring
# IN-117: Monitoring system IAM setup

# ============================================================================
# IAM Role for ECS Task - AMP Remote Write
# ============================================================================

# IAM Role for ECS tasks to write metrics to AMP
resource "aws_iam_role" "ecs-amp-writer" {
  name        = "${local.name_prefix}-ecs-amp-writer"
  description = "IAM role for ECS tasks to write metrics to Amazon Managed Prometheus"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-ecs-amp-writer"
      Component   = "iam"
      Description = "ECS task role for AMP remote write access"
    }
  )
}

# IAM Policy for AMP Remote Write
resource "aws_iam_role_policy" "amp-remote-write" {
  name = "amp-remote-write-policy"
  role = aws_iam_role.ecs-amp-writer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ]
        Resource = aws_prometheus_workspace.main.arn
      }
    ]
  })
}

# ============================================================================
# IAM Role for Grafana - AMP Data Source Access
# ============================================================================

# IAM Role for Grafana to query AMP
resource "aws_iam_role" "grafana-amp-reader" {
  name        = "${local.name_prefix}-grafana-amp-reader"
  description = "IAM role for Grafana to query Amazon Managed Prometheus"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "grafana.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          StringLike = {
            "aws:SourceArn" = "arn:aws:grafana:${var.aws_region}:${data.aws_caller_identity.current.account_id}:/workspaces/*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-grafana-amp-reader"
      Component   = "iam"
      Description = "Grafana role for AMP query access"
    }
  )
}

# IAM Policy for AMP Query Access
resource "aws_iam_role_policy" "amp-query" {
  name = "amp-query-policy"
  role = aws_iam_role.grafana-amp-reader.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:QueryMetrics",
          "aps:GetLabels",
          "aps:GetSeries",
          "aps:GetMetricMetadata"
        ]
        Resource = aws_prometheus_workspace.main.arn
      },
      {
        # ListWorkspaces and DescribeWorkspace require wildcard resource
        # https://docs.aws.amazon.com/prometheus/latest/userguide/AMP-APIReference.html
        Effect = "Allow"
        Action = [
          "aps:ListWorkspaces",
          "aps:DescribeWorkspace"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# IAM Role for Grafana - CloudWatch Data Source Access
# ============================================================================

# IAM Policy for CloudWatch Read Access
resource "aws_iam_role_policy" "cloudwatch-read" {
  name = "cloudwatch-read-policy"
  role = aws_iam_role.grafana-amp-reader.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch describe/list actions require wildcard resource
        # https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/permissions-reference-cw.html
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricWidgetImage"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = [
              "AWS/ECS",
              "AWS/RDS",
              "AWS/ApplicationELB",
              "ECS/ContainerInsights"
            ]
          }
        }
      },
      {
        # CloudWatch Logs actions limited to specific log groups
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/rds/*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
        ]
      },
      {
        # EC2 describe actions require wildcard resource
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        # Tag:GetResources requires wildcard resource
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# IAM Policy for ADOT Collector (ECS Task Role)
# ============================================================================

# Additional policy for ADOT Collector to collect ECS metrics
resource "aws_iam_role_policy" "adot-ecs-metrics" {
  name = "adot-ecs-metrics-policy"
  role = aws_iam_role.ecs-amp-writer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECS metadata endpoint access requires wildcard resource
        # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-metadata-endpoint.html
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks",
          "ecs:DescribeContainerInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ecs:cluster" = data.terraform_remote_state.atlantis.outputs.ecs_cluster_arn
          }
        }
      },
      {
        # EC2 describe actions require wildcard resource
        # https://docs.aws.amazon.com/AWSEC2/latest/APIReference/
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = [
              "ECS/ContainerInsights",
              "AWS/ECS"
            ]
          }
        }
      }
    ]
  })
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}

# ============================================================================
# Grafana Workspace IAM Role Association
# ============================================================================

# Associate IAM role with Grafana workspace for AMP data source
resource "aws_grafana_role_association" "amp" {
  role         = "ADMIN"
  workspace_id = aws_grafana_workspace.main.id
  user_ids     = [] # Add user IDs if using AWS SSO

  # This is managed through AMG console or API after workspace creation
  depends_on = [aws_grafana_workspace.main]

  lifecycle {
    ignore_changes = [user_ids]
  }
}
