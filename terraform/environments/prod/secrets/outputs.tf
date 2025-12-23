# Outputs for Secrets Manager Module

# KMS Key Outputs
output "secrets_manager_kms_key_id" {
  description = "KMS key ID used for Secrets Manager encryption"
  value       = local.secrets_manager_kms_key_id
}

output "secrets_manager_kms_key_arn" {
  description = "KMS key ARN used for Secrets Manager encryption"
  value       = local.secrets_manager_kms_key_arn
}

# Example Secret Outputs
output "example_secret_arns" {
  description = "ARNs of example secrets created"
  value = {
    for k, v in aws_secretsmanager_secret.example-secrets : k => v.arn
  }
}

output "example_secret_ids" {
  description = "IDs of example secrets created"
  value = {
    for k, v in aws_secretsmanager_secret.example-secrets : k => v.id
  }
}

# Lambda Rotation Outputs
output "rotation_lambda_arn" {
  description = "ARN of the rotation Lambda function"
  value       = module.rotation_lambda.function_arn
}

output "rotation_lambda_name" {
  description = "Name of the rotation Lambda function"
  value       = module.rotation_lambda.function_name
}

output "rotation_lambda_role_arn" {
  description = "ARN of the rotation Lambda execution role"
  value       = module.rotation_lambda_role.role_arn
}

output "rotation_lambda_role_name" {
  description = "Name of the rotation Lambda execution role"
  value       = module.rotation_lambda_role.role_name
}

output "rotation_lambda_security_group_id" {
  description = "Security group ID of the rotation Lambda function"
  value       = var.vpc_id != "" ? aws_security_group.rotation-lambda[0].id : null
}

# Secret Naming Pattern
output "secret_naming_pattern" {
  description = "Standard naming pattern for secrets"
  value       = "/${local.org_name}/{service}/{environment}/{name}"
}

output "rotation_schedule_days" {
  description = "Number of days between automatic rotations"
  value       = var.rotation_days
}

# IAM Policy ARN outputs for service repositories
output "crawler_secrets_read_policy_arn" {
  description = "ARN of the Crawler service secrets read policy"
  value       = aws_iam_policy.crawler-secrets-read.arn
}

output "market_secrets_read_policy_arn" {
  description = "ARN of the Market service secrets read policy"
  value       = aws_iam_policy.market-secrets-read.arn
}

# Market service secret outputs
output "market_db_secret_arn" {
  description = "ARN of the Market service database credentials secret"
  value       = aws_secretsmanager_secret.market-db.arn
}

output "market_db_secret_name" {
  description = "Name of the Market service database credentials secret"
  value       = aws_secretsmanager_secret.market-db.name
}

output "devops_secrets_management_policy_arn" {
  description = "ARN of the DevOps secrets management policy"
  value       = aws_iam_policy.devops-secrets-management.arn
}

output "github_actions_secrets_policy_arn" {
  description = "ARN of the GitHub Actions secrets policy"
  value       = aws_iam_policy.github-actions-secrets.arn
}
