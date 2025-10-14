# AWS Chatbot Configuration for Slack Notifications
# IN-118: Slack integration for alert notifications

# ============================================================================
# IAM Role for AWS Chatbot
# ============================================================================

# IAM Role for AWS Chatbot to publish messages to Slack
resource "aws_iam_role" "chatbot" {
  count       = var.enable_chatbot ? 1 : 0
  name        = "${local.name_prefix}-chatbot-role"
  description = "IAM role for AWS Chatbot to send notifications to Slack"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "chatbot.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-chatbot-role"
      Component   = "alerting"
      Description = "IAM role for AWS Chatbot Slack integration"
    }
  )
}

# IAM Policy for CloudWatch read access
resource "aws_iam_role_policy" "chatbot-cloudwatch" {
  count = var.enable_chatbot ? 1 : 0
  name  = "chatbot-cloudwatch-policy"
  role  = aws_iam_role.chatbot[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:Get*",
          "logs:List*",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:TestMetricFilter",
          "logs:FilterLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.alerting.account_id}:log-group:/aws/ecs/*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.alerting.account_id}:log-group:/aws/rds/*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.alerting.account_id}:log-group:/aws/lambda/*"
        ]
      }
    ]
  })
}

# ============================================================================
# AWS Chatbot Slack Configurations
# ============================================================================

# Chatbot configuration for Critical alerts
resource "aws_chatbot_slack_channel_configuration" "critical" {
  count              = var.enable_chatbot && var.slack_channel_id != "" ? 1 : 0
  configuration_name = "${local.name_prefix}-alerts"
  iam_role_arn       = aws_iam_role.chatbot[0].arn
  slack_channel_id   = var.slack_channel_id
  slack_team_id      = var.slack_workspace_id

  sns_topic_arns = [
    aws_sns_topic.critical.arn,
    aws_sns_topic.warning.arn,
    aws_sns_topic.info.arn
  ]

  guardrail_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]

  user_authorization_required = false
  logging_level               = "INFO"

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-alerts"
      Component   = "alerting"
      Severity    = "all"
      Description = "Chatbot configuration for all severity level alerts"
    }
  )
}

# ============================================================================
# Outputs
# ============================================================================

output "chatbot_role_arn" {
  description = "ARN of the AWS Chatbot IAM role"
  value       = var.enable_chatbot ? aws_iam_role.chatbot[0].arn : null
}

output "chatbot_config_arn" {
  description = "ARN of the Chatbot Slack configuration"
  value       = var.enable_chatbot && var.slack_channel_id != "" ? aws_chatbot_slack_channel_configuration.critical[0].chat_configuration_arn : null
}
