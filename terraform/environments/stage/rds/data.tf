# Data Sources

# VPC 정보
data "aws_vpc" "main" {
  id = var.vpc_id
}

# KMS 키 정보 (AWS 관리형 RDS 암호화 키)
data "aws_kms_key" "rds" {
  key_id = "alias/aws/rds"
}

# KMS 키 정보 (AWS 관리형 Secrets Manager 암호화 키)
data "aws_kms_key" "secrets_manager" {
  key_id = "alias/aws/secretsmanager"
}

# 현재 AWS 계정 정보
data "aws_caller_identity" "current" {}

# 현재 리전 정보
data "aws_region" "current" {}

# Production RDS snapshot (for refresh operations)
# This data source looks up the latest snapshot from prod
data "aws_db_snapshot" "prod_latest" {
  count = var.restore_from_snapshot && var.snapshot_identifier == null ? 1 : 0

  db_instance_identifier = "prod-shared-mysql"
  most_recent            = true
  snapshot_type          = "manual" # Use manual snapshots for controlled refresh
}
