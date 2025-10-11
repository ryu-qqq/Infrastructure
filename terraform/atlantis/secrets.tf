# AWS Secrets Manager for Atlantis GitHub credentials

resource "aws_secretsmanager_secret" "atlantis-github" {
  name                    = "atlantis/github-token-${var.environment}"
  description             = "GitHub Personal Access Token for Atlantis"
  recovery_window_in_days = 0 # Force immediate deletion to allow recreation

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-github-token-${var.environment}"
      Component   = "atlantis"
      Description = "GitHub credentials for Atlantis Terraform automation"
    }
  )
}

resource "aws_secretsmanager_secret_version" "atlantis-github" {
  secret_id = aws_secretsmanager_secret.atlantis-github.id
  secret_string = jsonencode({
    username = var.github_username
    token    = var.github_token
  })
}

# Outputs
output "atlantis_github_secret_arn" {
  description = "The ARN of the GitHub credentials secret"
  value       = aws_secretsmanager_secret.atlantis-github.arn
  sensitive   = true
}
