# ============================================================================
# RDS Proxy Configuration (Staging)
# ============================================================================
# RDS Proxy를 통한 커넥션 풀링으로 다음 문제를 해결합니다:
# - 다중 ECS 태스크의 커넥션 고갈 방지
# - 효율적인 커넥션 재사용 (90%+ 효율)
# - Staging 환경에서 Prod와 동일한 연결 패턴 검증
# ============================================================================

# RDS Proxy
resource "aws_db_proxy" "main" {
  count = var.enable_rds_proxy ? 1 : 0

  name                   = "${local.name_prefix}-proxy"
  debug_logging          = var.proxy_debug_logging
  engine_family          = "MYSQL"
  idle_client_timeout    = var.proxy_idle_client_timeout
  require_tls            = var.proxy_require_tls
  role_arn               = module.rds_proxy_role[0].role_arn
  vpc_security_group_ids = [module.rds_proxy_security_group[0].security_group_id]
  vpc_subnet_ids         = var.private_subnet_ids

  # Master user authentication
  auth {
    auth_scheme               = "SECRETS"
    client_password_auth_type = "MYSQL_NATIVE_PASSWORD"
    iam_auth                  = var.proxy_iam_auth ? "REQUIRED" : "DISABLED"
    secret_arn                = aws_secretsmanager_secret.db-master-password.arn
  }

  tags = merge(
    local.required_tags,
    var.tags,
    {
      Name      = "${local.name_prefix}-proxy"
      Component = "rds-proxy"
    }
  )

  depends_on = [
    module.rds,
    aws_secretsmanager_secret_version.db-master-password
  ]
}

# RDS Proxy Default Target Group
resource "aws_db_proxy_default_target_group" "main" {
  count = var.enable_rds_proxy ? 1 : 0

  db_proxy_name = aws_db_proxy.main[0].name

  connection_pool_config {
    connection_borrow_timeout    = var.proxy_connection_borrow_timeout
    max_connections_percent      = var.proxy_max_connections_percent
    max_idle_connections_percent = var.proxy_max_idle_connections_percent
  }
}

# RDS Proxy Target (RDS Instance)
resource "aws_db_proxy_target" "main" {
  count = var.enable_rds_proxy ? 1 : 0

  db_proxy_name          = aws_db_proxy.main[0].name
  target_group_name      = aws_db_proxy_default_target_group.main[0].name
  db_instance_identifier = module.rds.db_instance_identifier
}
