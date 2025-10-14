# SNS Topics and CloudWatch Alarms for Alerting System
# IN-118: Central alerting system with three severity levels

# ============================================================================
# Data Sources
# ============================================================================

# Get existing KMS key for encryption
data "aws_kms_key" "monitoring" {
  key_id = "alias/${var.environment}-monitoring"
}

# Get current account ID for ARNs
data "aws_caller_identity" "alerting" {}

# Get ECS cluster ARN from atlantis state
data "terraform_remote_state" "atlantis_alerting" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "atlantis/terraform.tfstate"
    region = var.aws_region
  }
}

# ============================================================================
# SNS Topics for Alert Severity Levels
# ============================================================================

# Critical Severity SNS Topic
resource "aws_sns_topic" "critical" {
  name              = "${local.name_prefix}-critical"
  display_name      = "Critical Alerts - ${var.environment}"
  kms_master_key_id = data.aws_kms_key.monitoring.id

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-critical"
      Component   = "alerting"
      Severity    = "critical"
      Description = "P0 critical alerts requiring immediate response"
    }
  )
}

# Warning Severity SNS Topic
resource "aws_sns_topic" "warning" {
  name              = "${local.name_prefix}-warning"
  display_name      = "Warning Alerts - ${var.environment}"
  kms_master_key_id = data.aws_kms_key.monitoring.id

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-warning"
      Component   = "alerting"
      Severity    = "warning"
      Description = "P1 warning alerts requiring attention within 30 minutes"
    }
  )
}

# Info Severity SNS Topic
resource "aws_sns_topic" "info" {
  name              = "${local.name_prefix}-info"
  display_name      = "Info Alerts - ${var.environment}"
  kms_master_key_id = data.aws_kms_key.monitoring.id

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-info"
      Component   = "alerting"
      Severity    = "info"
      Description = "P2 informational alerts for monitoring and analysis"
    }
  )
}

# ============================================================================
# SNS Topic Policies
# ============================================================================

# Allow CloudWatch to publish to Critical SNS Topic
resource "aws_sns_topic_policy" "critical" {
  arn = aws_sns_topic.critical.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.critical.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.alerting.account_id
          }
        }
      }
    ]
  })
}

# Allow CloudWatch to publish to Warning SNS Topic
resource "aws_sns_topic_policy" "warning" {
  arn = aws_sns_topic.warning.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.warning.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.alerting.account_id
          }
        }
      }
    ]
  })
}

# Allow CloudWatch to publish to Info SNS Topic
resource "aws_sns_topic_policy" "info" {
  arn = aws_sns_topic.info.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.info.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.alerting.account_id
          }
        }
      }
    ]
  })
}

# ============================================================================
# Email Subscriptions (Optional - for Critical Alerts)
# ============================================================================

# Email subscription for critical alerts
resource "aws_sns_topic_subscription" "critical-email" {
  count     = var.enable_critical_email_alerts ? 1 : 0
  topic_arn = aws_sns_topic.critical.arn
  protocol  = "email"
  endpoint  = var.critical_alert_email
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
    ClusterName = data.terraform_remote_state.atlantis_alerting.outputs.ecs_cluster_name
  }

  alarm_actions = [aws_sns_topic.critical.arn]
  ok_actions    = [aws_sns_topic.info.arn]

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
    ClusterName = data.terraform_remote_state.atlantis_alerting.outputs.ecs_cluster_name
  }

  alarm_actions = [aws_sns_topic.critical.arn]
  ok_actions    = [aws_sns_topic.info.arn]

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
    ClusterName = data.terraform_remote_state.atlantis_alerting.outputs.ecs_cluster_name
  }

  alarm_actions = [aws_sns_topic.warning.arn]
  ok_actions    = [aws_sns_topic.info.arn]

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
    ClusterName = data.terraform_remote_state.atlantis_alerting.outputs.ecs_cluster_name
  }

  alarm_actions = [aws_sns_topic.warning.arn]
  ok_actions    = [aws_sns_topic.info.arn]

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

# ============================================================================
# Outputs
# ============================================================================

output "sns_topic_critical_arn" {
  description = "ARN of the Critical severity SNS topic"
  value       = aws_sns_topic.critical.arn
}

output "sns_topic_warning_arn" {
  description = "ARN of the Warning severity SNS topic"
  value       = aws_sns_topic.warning.arn
}

output "sns_topic_info_arn" {
  description = "ARN of the Info severity SNS topic"
  value       = aws_sns_topic.info.arn
}
