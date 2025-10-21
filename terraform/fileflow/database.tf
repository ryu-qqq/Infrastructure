# Database Configuration for FileFlow

# ============================================================================
# Secrets Manager Secret for FileFlow Database Credentials
# ============================================================================

resource "aws_secretsmanager_secret" "fileflow-db" {
  name        = "fileflow/database/credentials"
  description = "FileFlow database credentials and connection information"
  kms_key_id  = local.secrets_manager_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-db-credentials"
      Component = "secrets-manager"
    }
  )
}

resource "aws_secretsmanager_secret_version" "fileflow-db" {
  secret_id = aws_secretsmanager_secret.fileflow-db.id

  secret_string = jsonencode({
    username = local.db_username
    password = local.db_credentials.password
    engine   = "mysql"
    host     = local.rds_endpoint
    port     = local.rds_port
    dbname   = var.database_name
    jdbc_url = "jdbc:mysql://${local.rds_endpoint}:${local.rds_port}/${var.database_name}?useSSL=true&requireSSL=true&serverTimezone=UTC&characterEncoding=UTF-8"
  })
}

# ============================================================================
# Security Group Rule for RDS Access
# ============================================================================

resource "aws_security_group_rule" "rds-from-ecs" {
  type                     = "ingress"
  from_port                = local.rds_port
  to_port                  = local.rds_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs-tasks.id
  security_group_id        = data.aws_db_instance.main.vpc_security_groups[0]
  description              = "Allow FileFlow ECS tasks to access RDS"
}
