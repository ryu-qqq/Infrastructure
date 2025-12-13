# AWS Secrets Manager for n8n

# =============================================================================
# Random Password Generation
# =============================================================================

# Generate random password for database (always auto-generated for security)
resource "random_password" "db-password" {
  length  = 32
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Generate random encryption key for n8n (always auto-generated for security)
resource "random_password" "n8n-encryption-key" {
  length  = 64
  special = false
}

# =============================================================================
# Database Password Secret
# =============================================================================

resource "aws_secretsmanager_secret" "n8n-db-password" {
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

resource "aws_secretsmanager_secret_version" "n8n-db-password" {
  secret_id = aws_secretsmanager_secret.n8n-db-password.id
  secret_string = jsonencode({
    password = random_password.db-password.result
  })
}

# =============================================================================
# Encryption Key Secret
# =============================================================================

resource "aws_secretsmanager_secret" "n8n-encryption-key" {
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

resource "aws_secretsmanager_secret_version" "n8n-encryption-key" {
  secret_id = aws_secretsmanager_secret.n8n-encryption-key.id
  secret_string = jsonencode({
    encryption_key = random_password.n8n-encryption-key.result
  })
}

# =============================================================================
# Outputs
# =============================================================================

output "db_password_secret_arn" {
  description = "The ARN of the database password secret"
  value       = aws_secretsmanager_secret.n8n-db-password.arn
  sensitive   = true
}

output "encryption_key_secret_arn" {
  description = "The ARN of the encryption key secret"
  value       = aws_secretsmanager_secret.n8n-encryption-key.arn
  sensitive   = true
}
