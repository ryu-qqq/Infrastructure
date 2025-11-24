# --- Repository Outputs ---

output "repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "The ARN of the ECR repository"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "The name of the ECR repository"
  value       = aws_ecr_repository.this.name
}

output "registry_id" {
  description = "The registry ID where the repository was created"
  value       = aws_ecr_repository.this.registry_id
}

# --- SSM Parameter Output ---

output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter storing repository URL"
  value       = var.create_ssm_parameter ? aws_ssm_parameter.repository-url[0].arn : null
}
