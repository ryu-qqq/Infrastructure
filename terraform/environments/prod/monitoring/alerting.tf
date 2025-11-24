# SNS Topics and CloudWatch Alarms for Alerting System
# IN-118: Central alerting system with three severity levels

# ============================================================================
# SNS Topics for Alert Severity Levels
# ============================================================================

# Critical Severity SNS Topic
module "sns_critical" {
  source = "../../../modules/sns"

  name         = local.sns_topics.critical
  display_name = "Critical Alerts - ${var.environment}"
  kms_key_id   = aws_kms_key.monitoring.id

  # Subscription for email alerts (optional)
  subscriptions = var.enable_critical_email_alerts && var.critical_alert_email != "" ? {
    email = {
      protocol = "email"
      endpoint = var.critical_alert_email
    }
  } : {}

  # Topic policy for CloudWatch to publish
  topic_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = "arn:aws:sns:${local.aws_region}:${local.aws_account_id}:${local.sns_topics.critical}"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.aws_account_id
          }
        }
      }
    ]
  })

  # CloudWatch alarms (disabled for this topic - alarm notifications handled at alarm level)
  enable_cloudwatch_alarms = false

  # Required tag variables
  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = "infrastructure"
  data_class  = var.data_class

  # Additional tags
  additional_tags = {
    Component   = "alerting"
    Severity    = "critical"
    Description = "P0 critical alerts requiring immediate response"
  }
}

# Warning Severity SNS Topic
module "sns_warning" {
  source = "../../../modules/sns"

  name         = local.sns_topics.warning
  display_name = "Warning Alerts - ${var.environment}"
  kms_key_id   = aws_kms_key.monitoring.id

  # Topic policy for CloudWatch to publish
  topic_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = "arn:aws:sns:${local.aws_region}:${local.aws_account_id}:${local.sns_topics.warning}"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.aws_account_id
          }
        }
      }
    ]
  })

  # CloudWatch alarms (disabled for this topic)
  enable_cloudwatch_alarms = false

  # Required tag variables
  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = "infrastructure"
  data_class  = var.data_class

  # Additional tags
  additional_tags = {
    Component   = "alerting"
    Severity    = "warning"
    Description = "P1 warning alerts requiring attention within 30 minutes"
  }
}

# Info Severity SNS Topic
module "sns_info" {
  source = "../../../modules/sns"

  name         = local.sns_topics.info
  display_name = "Info Alerts - ${var.environment}"
  kms_key_id   = aws_kms_key.monitoring.id

  # Topic policy for CloudWatch to publish
  topic_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = "arn:aws:sns:${local.aws_region}:${local.aws_account_id}:${local.sns_topics.info}"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.aws_account_id
          }
        }
      }
    ]
  })

  # CloudWatch alarms (disabled for this topic)
  enable_cloudwatch_alarms = false

  # Required tag variables
  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = "infrastructure"
  data_class  = var.data_class

  # Additional tags
  additional_tags = {
    Component   = "alerting"
    Severity    = "info"
    Description = "P2 informational alerts for monitoring and analysis"
  }
}

# ============================================================================
# CloudWatch Alarms - ECS
# ============================================================================

# Critical: ECS Task Count Zero
resource "aws_cloudwatch_metric_alarm" "ecs-task-count-zero" {
  count               = var.enable_ecs_alarms ? 1 : 0
  alarm_name          = "${local.name_prefix}-ecs-task-count-zero"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DesiredTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "All ECS tasks have stopped - immediate attention required"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = data.terraform_remote_state.atlantis.outputs.atlantis_ecs_cluster_name
  }

  alarm_actions = [module.sns_critical.topic_arn]
  ok_actions    = [module.sns_info.topic_arn]

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-task-count-zero"
      Component = "alerting"
      Severity  = "critical"
      Resource  = "ECS"
    }
  )
}

# Critical: ECS High Memory (95%)
resource "aws_cloudwatch_metric_alarm" "ecs-high-memory-critical" {
  count               = var.enable_ecs_alarms ? 1 : 0
  alarm_name          = "${local.name_prefix}-ecs-high-memory-critical"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "MemoryUtilization"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 95
  alarm_description   = "ECS memory utilization above 95% - memory exhaustion risk"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = data.terraform_remote_state.atlantis.outputs.atlantis_ecs_cluster_name
  }

  alarm_actions = [module.sns_critical.topic_arn]
  ok_actions    = [module.sns_info.topic_arn]

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-high-memory-critical"
      Component = "alerting"
      Severity  = "critical"
      Resource  = "ECS"
    }
  )
}

# Warning: ECS High CPU (80%)
resource "aws_cloudwatch_metric_alarm" "ecs-high-cpu-warning" {
  count               = var.enable_ecs_alarms ? 1 : 0
  alarm_name          = "${local.name_prefix}-ecs-high-cpu-warning"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU utilization above 80% for 10 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = data.terraform_remote_state.atlantis.outputs.atlantis_ecs_cluster_name
  }

  alarm_actions = [module.sns_warning.topic_arn]
  ok_actions    = [module.sns_info.topic_arn]

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-high-cpu-warning"
      Component = "alerting"
      Severity  = "warning"
      Resource  = "ECS"
    }
  )
}

# Warning: ECS High Memory (80%)
resource "aws_cloudwatch_metric_alarm" "ecs-high-memory-warning" {
  count               = var.enable_ecs_alarms ? 1 : 0
  alarm_name          = "${local.name_prefix}-ecs-high-memory-warning"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS memory utilization above 80% for 10 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = data.terraform_remote_state.atlantis.outputs.atlantis_ecs_cluster_name
  }

  alarm_actions = [module.sns_warning.topic_arn]
  ok_actions    = [module.sns_info.topic_arn]

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-high-memory-warning"
      Component = "alerting"
      Severity  = "warning"
      Resource  = "ECS"
    }
  )
}

# ============================================================================
# CloudWatch Alarms - RDS (Placeholder for future implementation)
# ============================================================================

# Note: RDS alarms will be added when RDS resources are deployed
# Planned alarms:
# - Critical: RDS Connection Failed (connections > 95% of max)
# - Critical: RDS CPU Critical (> 90%)
# - Warning: RDS High Latency (> 50ms)
# - Warning: RDS Free Memory Low (< 1GB)

# ============================================================================
# CloudWatch Alarms - ALB (Placeholder for future implementation)
# ============================================================================

# Note: ALB alarms will be added when ALB resources are deployed
# Planned alarms:
# - Critical: ALB High 5xx Error Rate (> 10%)
# - Critical: ALB No Healthy Targets
# - Warning: ALB High Response Time (p99 > 2s)
# - Warning: ALB Elevated 4xx Rate (> 15%)
