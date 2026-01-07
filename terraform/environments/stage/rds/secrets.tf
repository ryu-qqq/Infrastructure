# Random Password Generation
# Note: When restoring from snapshot, this password is only used if you manually reset it

resource "random_password" "master" {
  length  = 32
  special = true
  # MySQL에서 사용할 수 없는 특수문자 제외
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Cleanup any existing secret scheduled for deletion
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
resource "aws_secretsmanager_secret" "db-master-password" {
  depends_on              = [null_resource.cleanup_secret]
  name                    = "${local.name_prefix}-master-password"
  description             = "Master credentials and connection info for staging shared MySQL RDS instance"
  recovery_window_in_days = 0 # Force deletion to allow immediate recreation
  kms_key_id              = data.aws_kms_key.secrets_manager.arn

  lifecycle {
    create_before_destroy = false
  }

  tags = merge(
    local.required_tags,
    var.tags,
    {
      Name = "${local.name_prefix}-master-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db-master-password" {
  secret_id = aws_secretsmanager_secret.db-master-password.id
  secret_string = jsonencode({
    # Standard RDS secret format
    username = var.master_username
    password = random_password.master.result
    engine   = "mysql"
    host     = module.rds.db_instance_address
    port     = module.rds.db_instance_port
    dbname   = var.database_name

    # Additional metadata for applications
    connection_string = "mysql://${var.master_username}:${random_password.master.result}@${module.rds.db_instance_address}:${module.rds.db_instance_port}/${var.database_name}"
    environment       = var.environment
    multi_az          = var.enable_multi_az
    storage_encrypted = var.storage_encrypted

    # Staging-specific metadata
    restore_from_snapshot = var.restore_from_snapshot
    note                  = "Staging DB - data may be refreshed monthly from production"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
