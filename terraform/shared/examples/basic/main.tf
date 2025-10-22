# Shared Resources Reference Example
#
# 이 예제는 shared 패키지에서 생성된 공유 리소스를
# 다른 Terraform 모듈에서 참조하는 방법을 보여줍니다.

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 Backend for State Management
  backend "s3" {
    bucket         = "ryuqqq-prod-tfstate"
    key            = "examples/shared-reference/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
    kms_key_id     = "alias/terraform-state"
  }
}

provider "aws" {
  region = var.aws_region
}

# Shared 패키지의 Terraform State 참조
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "ryuqqq-prod-tfstate"
    key    = "shared/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# KMS 패키지의 Terraform State 참조
data "terraform_remote_state" "kms" {
  backend = "s3"
  config = {
    bucket = "ryuqqq-prod-tfstate"
    key    = "kms/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Network 패키지의 Terraform State 참조
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "ryuqqq-prod-tfstate"
    key    = "network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Locals for required tags (공유 리소스에서 가져온 태그 사용)
locals {
  required_tags = data.terraform_remote_state.shared.outputs.required_tags

  # 추가 태그
  additional_tags = {
    Component = "example-application"
  }
}

# 예제: S3 버킷 생성 (공유 KMS 키 사용)
resource "aws_s3_bucket" "example" {
  bucket = "example-app-${var.environment}-${var.aws_region}"

  tags = merge(
    local.required_tags,
    local.additional_tags,
    {
      Name = "s3-example-app"
    }
  )
}

# S3 버킷 암호화 (공유 KMS 키 사용)
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = data.terraform_remote_state.kms.outputs.terraform_state_key_arn
    }
  }
}

# 예제: CloudWatch Log Group 생성 (공유 설정 사용)
resource "aws_cloudwatch_log_group" "example" {
  name              = "/app/example/${var.environment}"
  retention_in_days = 7

  tags = merge(
    local.required_tags,
    local.additional_tags,
    {
      Name = "logs-example-app"
    }
  )
}

# 예제: VPC 정보 참조
output "vpc_id" {
  description = "VPC ID from shared network"
  value       = data.terraform_remote_state.network.outputs.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs from shared network"
  value       = data.terraform_remote_state.network.outputs.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs from shared network"
  value       = data.terraform_remote_state.network.outputs.public_subnet_ids
}
