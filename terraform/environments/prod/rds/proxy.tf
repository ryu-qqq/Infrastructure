# ============================================================================
# RDS Proxy Configuration
# ============================================================================
# RDS Proxy를 통한 커넥션 풀링으로 다음 문제를 해결합니다:
# - 다중 ECS 태스크의 커넥션 고갈 방지
# - 효율적인 커넥션 재사용 (90%+ 효율)
# - Multi-AZ Failover 시 자동 연결 전환
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

  auth {
    auth_scheme               = "SECRETS"
    client_password_auth_type = "MYSQL_NATIVE_PASSWORD"
    iam_auth                  = var.proxy_iam_auth ? "REQUIRED" : "DISABLED"
    secret_arn                = aws_secretsmanager_secret.db-master-password.arn
  }

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
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

# RDS Proxy Endpoint (Read/Write - Primary)
# 기본 엔드포인트는 Proxy 생성 시 자동으로 만들어짐

# Optional: Read-Only Endpoint (향후 Read Replica 추가 시 사용)
# resource "aws_db_proxy_endpoint" "read_only" {
#   count = var.enable_rds_proxy && var.enable_proxy_read_endpoint ? 1 : 0
#
#   db_proxy_name          = aws_db_proxy.main[0].name
#   db_proxy_endpoint_name = "${local.name_prefix}-proxy-ro"
#   vpc_subnet_ids         = var.private_subnet_ids
#   target_role            = "READ_ONLY"
#
#   tags = merge(
#     local.common_tags,
#     {
#       Name      = "${local.name_prefix}-proxy-ro"
#       Component = "rds-proxy-readonly"
#     }
#   )
# }
