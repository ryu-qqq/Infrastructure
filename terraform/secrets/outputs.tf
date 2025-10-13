# Outputs for Secrets Manager Module

output "secrets_manager_kms_key_id" {
  description = "KMS key ID used for Secrets Manager encryption"
  value       = local.secrets_manager_kms_key_id
}

output "secrets_manager_kms_key_arn" {
  description = "KMS key ARN used for Secrets Manager encryption"
  value       = data.terraform_remote_state.kms.outputs.secrets_manager_key_arn
}

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

output "rotation_lambda_arn" {
  description = "ARN of the rotation Lambda function"
  value       = aws_lambda_function.rotation.arn
}

output "rotation_lambda_role_arn" {
  description = "ARN of the rotation Lambda execution role"
  value       = aws_iam_role.rotation-lambda.arn
}

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

output "devops_secrets_management_policy_arn" {
  description = "ARN of the DevOps secrets management policy"
  value       = aws_iam_policy.devops-secrets-management.arn
}

output "github_actions_secrets_policy_arn" {
  description = "ARN of the GitHub Actions secrets policy"
  value       = aws_iam_policy.github-actions-secrets.arn
}
