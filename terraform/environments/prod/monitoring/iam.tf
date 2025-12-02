# IAM Roles and Policies for AMP/AMG Monitoring
# IN-117: Monitoring system IAM setup

# ============================================================================
# IAM Role for ECS Task - AMP Remote Write
# ============================================================================

module "iam_ecs_amp_writer" {
  source = "../../../modules/iam-role-policy"

  role_name   = local.iam_roles.ecs_amp_writer
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

  # Custom inline policy for AMP remote write
  custom_inline_policies = {
    amp-remote-write = {
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

    # ADOT Collector ECS metrics policy
    adot-ecs-metrics = {
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
                "ecs:cluster" = data.terraform_remote_state.atlantis.outputs.atlantis_ecs_cluster_arn
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
  }

  # Required tag variables
  environment  = var.environment
  service_name = var.service
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = "infrastructure"
  data_class   = var.data_class

  # Additional tags
  additional_tags = {
    Component = "iam"
  }
}

# ============================================================================
# IAM Role for Grafana - AMP Data Source Access
# ============================================================================

module "iam_grafana_amp_reader" {
  source = "../../../modules/iam-role-policy"

  role_name   = local.iam_roles.grafana_amp_reader
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
            "aws:SourceAccount" = local.aws_account_id
          }
          StringLike = {
            "aws:SourceArn" = "arn:aws:grafana:${local.aws_region}:${local.aws_account_id}:/workspaces/*"
          }
        }
      }
    ]
  })

  # Custom inline policies for AMP query and CloudWatch read access
  custom_inline_policies = {
    amp-query = {
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

    cloudwatch-read = {
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
            # CloudWatch GetMetricData/GetMetricStatistics require wildcard resource
            # Namespace conditions may not work reliably with GetMetricData API
            # https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/iam-cw-condition-keys-namespace.html
            Effect = "Allow"
            Action = [
              "cloudwatch:GetMetricStatistics",
              "cloudwatch:GetMetricData",
              "cloudwatch:GetMetricWidgetImage"
            ]
            Resource = "*"
          },
          {
            # DescribeLogGroups requires wildcard resource to list all log groups
            # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/iam-access-control-overview-cwl.html
            Effect = "Allow"
            Action = [
              "logs:DescribeLogGroups"
            ]
            Resource = "*"
          },
          {
            # CloudWatch Logs actions limited to specific log groups
            Effect = "Allow"
            Action = [
              "logs:GetLogGroupFields",
              "logs:StartQuery",
              "logs:StopQuery",
              "logs:GetQueryResults",
              "logs:GetLogEvents",
              "logs:FilterLogEvents"
            ]
            Resource = [
              "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:log-group:/aws/ecs/*",
              "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:log-group:/aws/rds/*",
              "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:log-group:/aws/lambda/*"
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
  }

  # Required tag variables
  environment  = var.environment
  service_name = var.service
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = "infrastructure"
  data_class   = var.data_class

  # Additional tags
  additional_tags = {
    Component = "iam"
  }
}

# ============================================================================
# Grafana Workspace IAM Role Association
# ============================================================================

# NOTE: This resource requires extensive SSO permissions and is better managed
# through the AMG console after workspace creation. Commenting out to avoid
# complex SSO permission requirements during initial deployment.
# resource "aws_grafana_role_association" "amp" {
#   role         = "ADMIN"
#   workspace_id = aws_grafana_workspace.main.id
#   user_ids     = [] # Add user IDs if using AWS SSO
#
#   # This is managed through AMG console or API after workspace creation
#   depends_on = [aws_grafana_workspace.main]
#
#   lifecycle {
#     ignore_changes = [user_ids]
#   }
# }
