# ============================================================================
# Outputs
# ============================================================================

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "RDS instance connection endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "RDS instance hostname"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "Master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_master_user_secret_arn" {
  description = "ARN of the master user secret in AWS Secrets Manager"
  value       = length(aws_db_instance.main.master_user_secret) > 0 ? aws_db_instance.main.master_user_secret[0].secret_arn : null
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = "prod-shared-mysql-subnet-group" # 기존 리소스 직접 참조 (import 불가)
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.main.id
}

# ============================================================================
# SSM Parameters for Cross-Stack References
# ============================================================================

resource "aws_ssm_parameter" "db-endpoint" {
  name        = "/shared/${var.project_name}/database/${var.db_identifier}/endpoint"
  description = "Database endpoint for cross-stack references"
  type        = "String"
  value       = aws_db_instance.main.endpoint

  tags = merge(
    local.required_tags,
    {
      Name      = "db-endpoint-export"
      Component = "database"
    }
  )
}

resource "aws_ssm_parameter" "db-address" {
  name        = "/shared/${var.project_name}/database/${var.db_identifier}/address"
  description = "Database address for cross-stack references"
  type        = "String"
  value       = aws_db_instance.main.address

  tags = merge(
    local.required_tags,
    {
      Name      = "db-address-export"
      Component = "database"
    }
  )
}

resource "aws_ssm_parameter" "db-port" {
  name        = "/shared/${var.project_name}/database/${var.db_identifier}/port"
  description = "Database port for cross-stack references"
  type        = "String"
  value       = tostring(aws_db_instance.main.port)

  tags = merge(
    local.required_tags,
    {
      Name      = "db-port-export"
      Component = "database"
    }
  )
}

resource "aws_ssm_parameter" "db-name" {
  name        = "/shared/${var.project_name}/database/${var.db_identifier}/database-name"
  description = "Database name for cross-stack references"
  type        = "String"
  value       = aws_db_instance.main.db_name

  tags = merge(
    local.required_tags,
    {
      Name      = "db-name-export"
      Component = "database"
    }
  )
}

# NOTE: 기존 RDS는 Secrets Manager를 사용하지 않으므로 secret-arn SSM Parameter는 생성하지 않음
# 새로운 RDS 생성 시에는 manage_master_user_password = true가 설정되어 secret이 자동 생성됨

resource "aws_ssm_parameter" "security-group-id" {
  name        = "/shared/${var.project_name}/database/${var.db_identifier}/security-group-id"
  description = "Database security group ID for cross-stack references"
  type        = "String"
  value       = aws_security_group.main.id

  tags = merge(
    local.required_tags,
    {
      Name      = "db-sg-export"
      Component = "database"
    }
  )
}
