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
# Shared API/MCP Database User
# =============================================================================

# Generate random password for shared API/MCP database user
resource "random_password" "shared-api-db-password" {
  length  = 32
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "shared-api-db-credentials" {
  name                    = "shared-api/db-credentials-${var.environment}"
  description             = "PostgreSQL credentials for shared API/MCP services"
  recovery_window_in_days = 7

  tags = merge(
    local.required_tags,
    {
      Name        = "shared-api-db-credentials-${var.environment}"
      Description = "PostgreSQL credentials for shared API/MCP services"
      Component   = "shared-api"
    }
  )
}

resource "aws_secretsmanager_secret_version" "shared-api-db-credentials" {
  secret_id = aws_secretsmanager_secret.shared-api-db-credentials.id
  secret_string = jsonencode({
    username = local.shared_api_db_username
    password = random_password.shared-api-db-password.result
    host     = module.n8n_rds.db_instance_endpoint
    port     = local.db_port
    dbname   = local.shared_api_db_name
    # Full connection string for convenience
    connection_url = "postgresql://${local.shared_api_db_username}:${random_password.shared-api-db-password.result}@${module.n8n_rds.db_instance_endpoint}:${local.db_port}/${local.shared_api_db_name}"
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

output "shared_api_db_credentials_secret_arn" {
  description = "The ARN of the shared API/MCP database credentials secret"
  value       = aws_secretsmanager_secret.shared-api-db-credentials.arn
  sensitive   = true
}

output "shared_api_db_credentials_secret_name" {
  description = "The name of the shared API/MCP database credentials secret"
  value       = aws_secretsmanager_secret.shared-api-db-credentials.name
}
