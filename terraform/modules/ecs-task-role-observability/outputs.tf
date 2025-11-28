# ============================================================================
# IAM Role Outputs
# ============================================================================

output "role_arn" {
  description = "ARN of the ECS Task Role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the ECS Task Role"
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "ID of the ECS Task Role"
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
    var.enable_combined_observability_policy ? ["${var.role_name}-observability"] : [],
    !var.enable_combined_observability_policy && var.enable_xray_policy ? ["${var.role_name}-xray"] : [],
    !var.enable_combined_observability_policy && var.enable_cloudwatch_logs_policy ? ["${var.role_name}-cloudwatch-logs"] : [],
    !var.enable_combined_observability_policy && var.enable_cloudwatch_metrics_policy ? ["${var.role_name}-cloudwatch-metrics"] : [],
    [for k, v in var.custom_inline_policies : "${var.role_name}-${k}"]
  )
}

# ============================================================================
# Observability Configuration Outputs
# ============================================================================

output "observability_enabled" {
  description = "Map of enabled observability features"
  value = {
    xray              = var.enable_combined_observability_policy || var.enable_xray_policy
    cloudwatch_logs   = var.enable_combined_observability_policy || var.enable_cloudwatch_logs_policy
    cloudwatch_metrics = var.enable_combined_observability_policy || var.enable_cloudwatch_metrics_policy
  }
}

output "metric_namespaces" {
  description = "CloudWatch metric namespaces allowed for this role"
  value       = var.cloudwatch_metric_namespaces
}
