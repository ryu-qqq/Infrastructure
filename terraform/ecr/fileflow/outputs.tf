# ECR Repository Outputs

output "repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.fileflow.repository_url
}

output "repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.fileflow.arn
}

output "repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.fileflow.name
}

# ============================================================================
# SSM Parameter Store Exports for Cross-Stack References
# ============================================================================

resource "aws_ssm_parameter" "repository-url" {
  name        = "/shared/ecr/fileflow-repository-url"
  description = "FileFlow ECR repository URL for cross-stack references"
  type        = "String"
  value       = aws_ecr_repository.fileflow.repository_url

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-repository-url-export"
      Component = "ecr"
    }
  )
}

resource "aws_ssm_parameter" "repository-arn" {
  name        = "/shared/ecr/fileflow-repository-arn"
  description = "FileFlow ECR repository ARN for cross-stack references"
  type        = "String"
  value       = aws_ecr_repository.fileflow.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-repository-arn-export"
      Component = "ecr"
    }
  )
}
