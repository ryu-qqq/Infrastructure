# ========================================
# Rule Outputs
# ========================================

output "rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.this.arn
}

output "rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.this.name
}

# ========================================
# IAM Role Outputs (ECS Target)
# ========================================

output "eventbridge_role_arn" {
  description = "ARN of the IAM role for EventBridge (ECS target only)"
  value       = var.target_type == "ecs" ? aws_iam_role.eventbridge[0].arn : null
}

output "eventbridge_role_name" {
  description = "Name of the IAM role for EventBridge (ECS target only)"
  value       = var.target_type == "ecs" ? aws_iam_role.eventbridge[0].name : null
}
