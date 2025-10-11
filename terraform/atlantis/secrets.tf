# AWS Secrets Manager for Atlantis GitHub credentials

resource "aws_secretsmanager_secret" "atlantis-github" {
  name                    = "atlantis/github-token-v2-${var.environment}"
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

# GitHub App credentials for Atlantis
resource "aws_secretsmanager_secret" "atlantis-github-app" {
  name                    = "atlantis/github-app-v2-${var.environment}"
  description             = "GitHub App credentials for Atlantis (App ID, Installation ID, Private Key)"
  recovery_window_in_days = 0 # Force immediate deletion to allow recreation

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-github-app-${var.environment}"
      Component   = "atlantis"
      Description = "GitHub App authentication for Atlantis Terraform automation"
    }
  )
}

resource "aws_secretsmanager_secret_version" "atlantis-github-app" {
  count     = var.github_app_id != "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.atlantis-github-app.id
  secret_string = jsonencode({
    app_id          = var.github_app_id
    installation_id = var.github_app_installation_id
    private_key     = var.github_app_private_key
  })
}

# GitHub Webhook Secret
resource "aws_secretsmanager_secret" "atlantis-webhook-secret" {
  name                    = "atlantis/webhook-secret-v2-${var.environment}"
  description             = "GitHub Webhook Secret for validating webhook requests"
  recovery_window_in_days = 0

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-webhook-secret-${var.environment}"
      Component   = "atlantis"
      Description = "Webhook secret for GitHub event validation"
    }
  )
}

resource "aws_secretsmanager_secret_version" "atlantis-webhook-secret" {
  count     = var.github_webhook_secret != "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.atlantis-webhook-secret.id
  secret_string = jsonencode({
    webhook_secret = var.github_webhook_secret
  })
}

# Outputs
output "atlantis_github_secret_arn" {
  description = "The ARN of the GitHub credentials secret"
  value       = aws_secretsmanager_secret.atlantis-github.arn
  sensitive   = true
}

output "atlantis_github_app_secret_arn" {
  description = "The ARN of the GitHub App credentials secret"
  value       = aws_secretsmanager_secret.atlantis-github-app.arn
  sensitive   = true
}

output "atlantis_webhook_secret_arn" {
  description = "The ARN of the GitHub Webhook secret"
  value       = aws_secretsmanager_secret.atlantis-webhook-secret.arn
  sensitive   = true
}
