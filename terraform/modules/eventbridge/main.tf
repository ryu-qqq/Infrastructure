# ========================================
# EventBridge Rule and Target
# ========================================

# Common Tags Module
module "tags" {
  source = "../common-tags"

  environment = var.environment
  service     = var.service_name
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project
  data_class  = var.data_class

  additional_tags = var.additional_tags
}

resource "aws_cloudwatch_event_rule" "this" {
  name                = var.name
  description         = var.description
  schedule_expression = var.schedule_expression
  event_pattern       = var.event_pattern
  state               = var.enabled ? "ENABLED" : "DISABLED"

  tags = merge(
    local.required_tags,
    {
      Name = var.name
    }
  )
}

# ========================================
# ECS Task Target
# ========================================

resource "aws_cloudwatch_event_target" "ecs" {
  count = var.target_type == "ecs" ? 1 : 0

  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "${var.name}-target"
  arn       = var.ecs_cluster_arn
  role_arn  = aws_iam_role.eventbridge[0].arn

  ecs_target {
    task_definition_arn = var.ecs_task_definition_arn
    task_count          = var.ecs_task_count
    launch_type         = var.ecs_launch_type

    dynamic "network_configuration" {
      for_each = var.ecs_network_configuration != null ? [var.ecs_network_configuration] : []
      content {
        subnets          = network_configuration.value.subnets
        security_groups  = network_configuration.value.security_groups
        assign_public_ip = network_configuration.value.assign_public_ip
      }
    }
  }
}

# ========================================
# Lambda Target
# ========================================

resource "aws_cloudwatch_event_target" "lambda" {
  count = var.target_type == "lambda" ? 1 : 0

  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "${var.name}-target"
  arn       = var.lambda_function_arn
}

resource "aws_lambda_permission" "eventbridge" {
  count = var.target_type == "lambda" ? 1 : 0

  statement_id  = "AllowEventBridgeInvoke-${var.name}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}

# ========================================
# SNS Target
# ========================================

resource "aws_cloudwatch_event_target" "sns" {
  count = var.target_type == "sns" ? 1 : 0

  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "${var.name}-target"
  arn       = var.sns_topic_arn
}

# ========================================
# SQS Target
# ========================================

resource "aws_cloudwatch_event_target" "sqs" {
  count = var.target_type == "sqs" ? 1 : 0

  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "${var.name}-target"
  arn       = var.sqs_queue_arn
}

# ========================================
# IAM Role for EventBridge (ECS Target)
# ========================================

resource "aws_iam_role" "eventbridge" {
  count = var.target_type == "ecs" ? 1 : 0

  name = "${var.name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-eventbridge-role"
    }
  )
}

resource "aws_iam_role_policy" "eventbridge_ecs" {
  count = var.target_type == "ecs" ? 1 : 0

  name = "${var.name}-ecs-run-task"
  role = aws_iam_role.eventbridge[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = [
          var.ecs_task_definition_arn,
          "${replace(var.ecs_task_definition_arn, "/:\\d+$/", "")}:*"
        ]
        Condition = {
          ArnLike = {
            "ecs:cluster" = var.ecs_cluster_arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = var.ecs_task_role_arns
        Condition = {
          StringLike = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}
