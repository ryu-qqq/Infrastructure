# Outputs for ECR FileFlow

output "repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.fileflow.repository_url
}

output "repository_arn" {
  description = "The ARN of the ECR repository"
  value       = aws_ecr_repository.fileflow.arn
}

output "repository_name" {
  description = "The name of the ECR repository"
  value       = aws_ecr_repository.fileflow.name
}

output "registry_id" {
  description = "The registry ID where the repository was created"
  value       = aws_ecr_repository.fileflow.registry_id
}

# ============================================================================
# SSM Parameter Store Exports for Cross-Stack References
# ============================================================================

resource "aws_ssm_parameter" "fileflow-repository-url" {
  name        = "/shared/ecr/fileflow-repository-url"
  description = "FileFlow ECR repository URL for cross-stack references"
  type        = "String"
  value       = aws_ecr_repository.fileflow.repository_url

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-ecr-repository-url-export"
      Component = "ecr"
    }
  )
}
