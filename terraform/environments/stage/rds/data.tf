# Data Sources

# VPC 정보
data "aws_vpc" "main" {
  id = var.vpc_id
}

# KMS 키는 kms.tf에서 고객 관리형 키로 직접 생성
# Zero-Tolerance: AWS 관리형 키(alias/aws/*) 사용 금지

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
