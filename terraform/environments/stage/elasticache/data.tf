# Data Sources

# VPC 정보
data "aws_vpc" "main" {
  id = var.vpc_id
}

# 현재 AWS 계정 정보
data "aws_caller_identity" "current" {}

# 현재 리전 정보
data "aws_region" "current" {}
