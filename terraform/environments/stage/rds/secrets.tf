# Random Password Generation
# Note: When restoring from snapshot, this password is only used if you manually reset it

resource "random_password" "master" {
  length  = 32
  special = true
  # MySQL에서 사용할 수 없는 특수문자 제외
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Note: 스냅샷 복원 시에도 random_password를 사용합니다.
# 스냅샷 복원 후 rds-stage-refresh.sh가 RDS 암호와 Secrets Manager를 자동으로 동기화합니다.

# Secrets Manager - Database Credentials
# 기존 시크릿이 삭제 대기 중인 경우 다음 명령어로 import:
# terraform import aws_secretsmanager_secret.db-master-password staging-shared-mysql-master-password
resource "aws_secretsmanager_secret" "db-master-password" {
  name                    = "${local.name_prefix}-master-password"
  description             = "Master credentials and connection info for staging shared MySQL RDS instance"
  recovery_window_in_days = 7 # Staging 환경에서도 7일간 복구 가능하도록 설정
  kms_key_id              = aws_kms_key.secrets_manager.arn

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
    # 암호는 항상 Terraform이 생성한 값 사용
    # 스냅샷 복원 시: rds-stage-refresh.sh가 RDS 암호 재설정 및 Secrets Manager 동기화 수행
    password = random_password.master.result
    engine   = "mysql"
    host     = module.rds.db_instance_address
    port     = module.rds.db_instance_port
    dbname   = var.database_name

    # 연결 메타데이터
    environment       = var.environment
    multi_az          = var.enable_multi_az
    storage_encrypted = var.storage_encrypted

    # Staging-specific metadata
    restore_from_snapshot = var.restore_from_snapshot
    note                  = "Staging DB - 스냅샷 복원 시 rds-stage-refresh.sh 실행 필요"
  })

  # lifecycle ignore_changes 제거 - DB 엔드포인트 변경 시 Secrets Manager도 업데이트되어야 함
}
