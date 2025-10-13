# ============================================
# Outputs for Atlantis IAM Configuration
# ============================================

output "atlantis_task_role_arn" {
  description = "ARN of the Atlantis ECS Task Role"
  value       = aws_iam_role.atlantis-task-role.arn
}

output "atlantis_task_role_name" {
  description = "Name of the Atlantis ECS Task Role"
  value       = aws_iam_role.atlantis-task-role.name
}

output "atlantis_target_prod_role_arn" {
  description = "ARN of the prod environment Target Role"
  value       = aws_iam_role.atlantis-target-prod.arn
}

output "atlantis_target_prod_role_name" {
  description = "Name of the prod environment Target Role"
  value       = aws_iam_role.atlantis-target-prod.name
}
