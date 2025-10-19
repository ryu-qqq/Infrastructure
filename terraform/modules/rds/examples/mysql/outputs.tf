# RDS 인스턴스 정보
output "db_instance_id" {
  description = "RDS 인스턴스 ID"
  value       = module.rds_mysql.db_instance_id
}

output "db_instance_arn" {
  description = "RDS 인스턴스 ARN"
  value       = module.rds_mysql.db_instance_arn
}

output "db_instance_endpoint" {
  description = "RDS 인스턴스 엔드포인트 (호스트:포트)"
  value       = module.rds_mysql.db_instance_endpoint
}

output "db_instance_address" {
  description = "RDS 인스턴스 호스트명"
  value       = module.rds_mysql.db_instance_address
}

output "db_instance_port" {
  description = "RDS 인스턴스 포트"
  value       = module.rds_mysql.db_instance_port
}

# 데이터베이스 정보
output "db_name" {
  description = "데이터베이스 이름"
  value       = module.rds_mysql.db_instance_name
}

output "master_username" {
  description = "마스터 사용자 이름"
  value       = module.rds_mysql.db_instance_username
  sensitive   = true
}

# 보안 및 네트워크
output "security_group_id" {
  description = "RDS 보안 그룹 ID"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_id" {
  description = "DB Subnet Group ID"
  value       = module.rds_mysql.db_subnet_group_id
}

# KMS 키
output "kms_key_id" {
  description = "RDS 암호화에 사용된 KMS 키 ID"
  value       = aws_kms_key.rds.id
}

output "kms_key_arn" {
  description = "RDS 암호화에 사용된 KMS 키 ARN"
  value       = aws_kms_key.rds.arn
}

# Secrets Manager
output "db_password_secret_arn" {
  description = "데이터베이스 비밀번호가 저장된 Secrets Manager ARN"
  value       = aws_secretsmanager_secret.db-password.arn
}

output "db_password_secret_name" {
  description = "데이터베이스 비밀번호가 저장된 Secrets Manager 이름"
  value       = aws_secretsmanager_secret.db-password.name
}

# CloudWatch 알람
output "cpu_alarm_arn" {
  description = "CPU 사용률 CloudWatch 알람 ARN"
  value       = aws_cloudwatch_metric_alarm.cpu-utilization.arn
}

output "storage_alarm_arn" {
  description = "스토리지 사용량 CloudWatch 알람 ARN"
  value       = aws_cloudwatch_metric_alarm.storage-space.arn
}

output "connections_alarm_arn" {
  description = "연결 수 CloudWatch 알람 ARN"
  value       = aws_cloudwatch_metric_alarm.database-connections.arn
}

# 연결 문자열 예시
output "connection_string_example" {
  description = "MySQL 연결 문자열 예시"
  value       = "mysql://${module.rds_mysql.db_instance_username}:[PASSWORD]@${module.rds_mysql.db_instance_address}:${module.rds_mysql.db_instance_port}/${module.rds_mysql.db_instance_name}"
  sensitive   = true
}

# 애플리케이션 환경 변수 예시
output "app_environment_variables" {
  description = "애플리케이션에서 사용할 환경 변수 예시"
  value = {
    DB_HOST     = module.rds_mysql.db_instance_address
    DB_PORT     = tostring(module.rds_mysql.db_instance_port)
    DB_NAME     = module.rds_mysql.db_instance_name
    DB_USERNAME = module.rds_mysql.db_instance_username
    # DB_PASSWORD는 Secrets Manager에서 가져오기
    DB_PASSWORD_SECRET_ARN = aws_secretsmanager_secret.db-password.arn
  }
}
