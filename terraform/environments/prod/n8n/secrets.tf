# AWS Secrets Manager for n8n

# =============================================================================
# Database Password Secret
# =============================================================================

resource "aws_secretsmanager_secret" "n8n_db_password" {
  name                    = "n8n/db-password-${var.environment}"
  description             = "PostgreSQL password for n8n database"
  recovery_window_in_days = 7

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-db-password"
      Description = "PostgreSQL password for n8n database"
    }
  )
}

resource "aws_secretsmanager_secret_version" "n8n_db_password" {
  secret_id = aws_secretsmanager_secret.n8n_db_password.id
  secret_string = jsonencode({
    password = var.db_password
  })
}

# =============================================================================
# Encryption Key Secret
# =============================================================================

resource "aws_secretsmanager_secret" "n8n_encryption_key" {
  name                    = "n8n/encryption-key-${var.environment}"
  description             = "Encryption key for n8n credentials"
  recovery_window_in_days = 7

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-encryption-key"
      Description = "Encryption key for n8n credentials storage"
    }
  )
}

resource "aws_secretsmanager_secret_version" "n8n_encryption_key" {
  secret_id = aws_secretsmanager_secret.n8n_encryption_key.id
  secret_string = jsonencode({
    encryption_key = var.n8n_encryption_key
  })
}

# =============================================================================
# Outputs
# =============================================================================

output "db_password_secret_arn" {
  description = "The ARN of the database password secret"
  value       = aws_secretsmanager_secret.n8n_db_password.arn
  sensitive   = true
}

output "encryption_key_secret_arn" {
  description = "The ARN of the encryption key secret"
  value       = aws_secretsmanager_secret.n8n_encryption_key.arn
  sensitive   = true
}
