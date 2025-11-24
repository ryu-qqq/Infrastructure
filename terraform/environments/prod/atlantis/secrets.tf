# AWS Secrets Manager for Atlantis GitHub App credentials
# Note: Secrets resources kept as raw resources (no module available)

resource "aws_secretsmanager_secret" "atlantis-github-app" {
  name                    = "atlantis/github-app-v2-${var.environment}"
  description             = "GitHub App credentials for Atlantis"
  recovery_window_in_days = 0 # Force immediate deletion to allow recreation

  tags = merge(
    local.common_tags,
    {
      Name        = "atlantis-github-app-${var.environment}"
      Component   = "atlantis"
      Description = "GitHub App credentials for Atlantis Terraform automation"
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

resource "aws_secretsmanager_secret" "atlantis-webhook-secret" {
  name                    = "atlantis/webhook-secret-v2-${var.environment}"
  description             = "GitHub Webhook Secret for Atlantis"
  recovery_window_in_days = 0 # Force immediate deletion to allow recreation

  tags = merge(
    local.common_tags,
    {
      Name        = "atlantis-webhook-secret-${var.environment}"
      Component   = "atlantis"
      Description = "GitHub webhook secret for validating webhook requests"
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
output "atlantis_github_app_secret_arn" {
  description = "The ARN of the GitHub App credentials secret"
  value       = aws_secretsmanager_secret.atlantis-github-app.arn
  sensitive   = true
}

output "atlantis_webhook_secret_arn" {
  description = "The ARN of the GitHub webhook secret"
  value       = aws_secretsmanager_secret.atlantis-webhook-secret.arn
  sensitive   = true
}
