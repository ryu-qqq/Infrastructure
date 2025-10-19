# Random Password Generation

resource "random_password" "master" {
  length  = 32
  special = true
  # MySQL에서 사용할 수 없는 특수문자 제외
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Secrets Manager - Master Password

resource "aws_secretsmanager_secret" "db-master-password" {
  name                    = "${local.name_prefix}-master-password"
  description             = "Master password for shared MySQL RDS instance"
  recovery_window_in_days = 7
  kms_key_id              = data.aws_kms_key.secrets_manager.arn

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
    username = var.master_username
    password = random_password.master.result
    engine   = "mysql"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.database_name
  })
}

# Secrets Manager - Connection String

resource "aws_secretsmanager_secret" "db-connection" {
  name                    = "${local.name_prefix}-connection"
  description             = "Connection information for shared MySQL RDS instance"
  recovery_window_in_days = 7
  kms_key_id              = data.aws_kms_key.secrets_manager.arn

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-connection"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db-connection" {
  secret_id = aws_secretsmanager_secret.db-connection.id
  secret_string = jsonencode({
    engine               = "mysql"
    host                 = aws_db_instance.main.address
    port                 = aws_db_instance.main.port
    dbname               = var.database_name
    username             = var.master_username
    password             = random_password.master.result
    connection_string    = "mysql://${var.master_username}:${random_password.master.result}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.database_name}"
    read_replica_host    = var.enable_multi_az ? aws_db_instance.main.address : null
    multi_az             = var.enable_multi_az
    storage_encrypted    = var.storage_encrypted
    kms_key_id           = data.aws_kms_key.rds.arn
    backup_retention     = var.backup_retention_period
    performance_insights = var.enable_performance_insights
  })
}
