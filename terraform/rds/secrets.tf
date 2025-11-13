# Random Password Generation

resource "random_password" "master" {
  length  = 32
  special = true
  # MySQL에서 사용할 수 없는 특수문자 제외
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Cleanup any existing secret scheduled for deletion
# This is necessary because recovery_window_in_days = 0 doesn't always work immediately
resource "null_resource" "cleanup_secret" {
  triggers = {
    secret_name = "${local.name_prefix}-master-password"
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws secretsmanager delete-secret \
        --secret-id ${local.name_prefix}-master-password \
        --force-delete-without-recovery \
        --region ${var.aws_region} 2>/dev/null || true
    EOT
  }
}

# Secrets Manager - Database Credentials
# Single source of truth for RDS credentials to prevent password sync issues during rotation

resource "aws_secretsmanager_secret" "db-master-password" {
  depends_on              = [null_resource.cleanup_secret]
  name                    = "${local.name_prefix}-master-password"
  description             = "Master credentials and connection info for shared MySQL RDS instance"
  recovery_window_in_days = 0 # Force deletion to allow immediate recreation
  kms_key_id              = data.aws_kms_key.secrets_manager.arn

  # Allow Terraform to manage secrets even if deletion is pending
  lifecycle {
    create_before_destroy = false
  }

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-master-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db-master-password" {
  secret_id = aws_secretsmanager_secret.db-master-password.id
  secret_string = jsonencode({
    # Standard RDS secret format for automatic rotation support
    username = var.master_username
    password = random_password.master.result
    engine   = "mysql"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.database_name

    # Additional metadata for applications
    connection_string    = "mysql://${var.master_username}:${random_password.master.result}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.database_name}"
    read_replica_host    = var.enable_multi_az ? aws_db_instance.main.address : null
    multi_az             = var.enable_multi_az
    storage_encrypted    = var.storage_encrypted
    kms_key_id           = data.aws_kms_key.rds.arn
    backup_retention     = var.backup_retention_period
    performance_insights = var.enable_performance_insights
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Reference to rotation Lambda from secrets module
data "terraform_remote_state" "secrets" {
  backend = "s3"
  config = {
    bucket = "prod-tfstate"
    key    = "secrets/terraform.tfstate"
    region = var.aws_region
  }
}

# Automatic rotation configuration for RDS master password
resource "aws_secretsmanager_secret_rotation" "db-master-password" {
  count = var.enable_secrets_rotation ? 1 : 0

  secret_id           = aws_secretsmanager_secret.db-master-password.id
  rotation_lambda_arn = data.terraform_remote_state.secrets.outputs.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }

  depends_on = [
    aws_secretsmanager_secret_version.db-master-password
  ]
}
