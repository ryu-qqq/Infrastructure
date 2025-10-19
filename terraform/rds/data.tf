# Data Sources

# VPC 정보
data "aws_vpc" "main" {
  id = var.vpc_id
}

# KMS 키 정보 (기존 생성된 RDS 암호화용 KMS 키)
data "aws_kms_key" "rds" {
  key_id = "alias/rds-encryption"
}

# KMS 키 정보 (Secrets Manager 암호화용)
data "aws_kms_key" "secrets_manager" {
  key_id = "alias/secrets-manager"
}

# 현재 AWS 계정 정보
data "aws_caller_identity" "current" {}

# 현재 리전 정보
data "aws_region" "current" {}

# Monitoring stack for SNS topic ARNs
data "terraform_remote_state" "monitoring" {
  backend = "s3"
  config = {
    bucket = "prod-connectly"
    key    = "monitoring/terraform.tfstate"
    region = var.aws_region
  }
}
