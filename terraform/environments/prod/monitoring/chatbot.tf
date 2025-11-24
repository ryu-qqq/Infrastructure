# AWS Chatbot Configuration for Slack Notifications
# IN-118: Slack integration for alert notifications

# ============================================================================
# IAM Role for AWS Chatbot
# ============================================================================

module "iam_chatbot" {
  count  = var.enable_chatbot ? 1 : 0
  source = "../../../modules/iam-role-policy"

  role_name   = local.iam_roles.chatbot
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

  # Custom inline policy for CloudWatch read access
  custom_inline_policies = {
    cloudwatch-read = {
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
              "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:log-group:/aws/ecs/*",
              "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:log-group:/aws/rds/*",
              "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:log-group:/aws/lambda/*"
            ]
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
    Component = "alerting"
  }
}

# ============================================================================
# AWS Chatbot Slack Configurations
# ============================================================================

# Chatbot configuration for all severity alerts
resource "aws_chatbot_slack_channel_configuration" "critical" {
  count              = var.enable_chatbot && var.slack_channel_id != "" ? 1 : 0
  configuration_name = "${local.name_prefix}-alerts"
  iam_role_arn       = module.iam_chatbot[0].role_arn
  slack_channel_id   = var.slack_channel_id
  slack_team_id      = var.slack_workspace_id

  sns_topic_arns = [
    module.sns_critical.topic_arn,
    module.sns_warning.topic_arn,
    module.sns_info.topic_arn
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
