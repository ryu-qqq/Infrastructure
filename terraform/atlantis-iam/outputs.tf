# ============================================
# Outputs for Atlantis IAM Configuration
# ============================================

output "atlantis_task_role_arn" {
  description = "ARN of the Atlantis ECS Task Role"
  value       = aws_iam_role.atlantis_task_role.arn
}

output "atlantis_task_role_name" {
  description = "Name of the Atlantis ECS Task Role"
  value       = aws_iam_role.atlantis_task_role.name
}

output "atlantis_target_dev_role_arn" {
  description = "ARN of the dev environment Target Role"
  value       = aws_iam_role.atlantis_target_dev.arn
}

output "atlantis_target_stg_role_arn" {
  description = "ARN of the stg environment Target Role"
  value       = aws_iam_role.atlantis_target_stg.arn
}

output "atlantis_target_prod_role_arn" {
  description = "ARN of the prod environment Target Role"
  value       = aws_iam_role.atlantis_target_prod.arn
}

output "target_roles" {
  description = "Map of environment to Target Role ARN"
  value = {
    dev  = aws_iam_role.atlantis_target_dev.arn
    stg  = aws_iam_role.atlantis_target_stg.arn
    prod = aws_iam_role.atlantis_target_prod.arn
  }
}
