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

# Monitoring stack for SNS topic ARNs
data "terraform_remote_state" "monitoring" {
  backend = "s3"
  config = {
    bucket = "prod-connectly"
    key    = "monitoring/terraform.tfstate"
    region = var.aws_region
  }
}
