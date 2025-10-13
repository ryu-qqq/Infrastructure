# Secrets Manager Resources

# Example Secrets - These demonstrate the structure
# In production, service-specific secrets would be managed in their respective modules
resource "aws_secretsmanager_secret" "example_secrets" {
  for_each = local.example_secrets

  name        = each.value.name
  description = each.value.description
  kms_key_id  = local.secrets_manager_kms_key_id

  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = merge(
    local.required_tags,
    {
      Name        = each.value.name
      SecretType  = each.value.type
      Lifecycle   = "permanent"
      AutoRotate  = var.enable_rotation ? "true" : "false"
    }
  )
}

# Example: RDS Secret with JSON structure
# This would typically be in a service-specific module
resource "random_password" "db_master" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret_version" "db_master" {
  secret_id = aws_secretsmanager_secret.example_secrets["db_master"].id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_master.result
    engine   = "postgres"
    host     = "example-db.ap-northeast-2.rds.amazonaws.com"
    port     = 5432
    dbname   = "exampledb"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Rotation configuration for RDS secret
resource "aws_secretsmanager_secret_rotation" "db_master" {
  count = var.enable_rotation ? 1 : 0

  secret_id           = aws_secretsmanager_secret.example_secrets["db_master"].id
  rotation_lambda_arn = aws_lambda_function.rotation.arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }

  depends_on = [
    aws_lambda_permission.allow_secrets_manager
  ]
}
