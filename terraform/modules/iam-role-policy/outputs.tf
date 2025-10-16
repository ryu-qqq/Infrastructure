# ============================================================================
# IAM Role Outputs
# ============================================================================

output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "ID of the IAM role"
  value       = aws_iam_role.this.id
}

output "role_unique_id" {
  description = "Unique ID assigned by AWS to the IAM role"
  value       = aws_iam_role.this.unique_id
}

# ============================================================================
# Policy Outputs
# ============================================================================

output "attached_policy_arns" {
  description = "List of AWS managed policy ARNs attached to the role"
  value       = var.attach_aws_managed_policies
}

output "inline_policy_names" {
  description = "List of inline policy names attached to the role"
  value = concat(
    var.enable_ecs_task_execution_policy ? ["${var.role_name}-ecs-task-execution"] : [],
    var.enable_ecs_task_policy ? ["${var.role_name}-ecs-task"] : [],
    var.enable_rds_policy ? ["${var.role_name}-rds-access"] : [],
    var.enable_secrets_manager_policy ? ["${var.role_name}-secrets-manager"] : [],
    var.enable_s3_policy ? ["${var.role_name}-s3-access"] : [],
    var.enable_cloudwatch_logs_policy ? ["${var.role_name}-cloudwatch-logs"] : [],
    [for k, v in var.custom_inline_policies : "${var.role_name}-${k}"]
  )
}
