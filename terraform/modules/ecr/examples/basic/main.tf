# ECR Basic Example
#
# 이 예제는 기본 ECR 리포지토리를 생성하는 방법을 보여줍니다.
# KMS 암호화, 이미지 스캔, 라이프사이클 정책이 포함되어 있습니다.

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Locals for required tags
locals {
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.resource_lifecycle
    DataClass   = var.data_class
    Service     = var.service
  }
}

# KMS Key for ECR Encryption
resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR ${var.repository_name} encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(
    local.required_tags,
    {
      Name      = "kms-ecr-${var.repository_name}"
      Component = "encryption"
    }
  )
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/ecr-${var.repository_name}"
  target_key_id = aws_kms_key.ecr.key_id
}

# ECR Repository
resource "aws_ecr_repository" "main" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  # KMS 암호화 설정
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  # 이미지 스캔 활성화
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "ecr-${var.repository_name}"
      Component = "container-registry"
    }
  )
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repository Policy (Optional)
resource "aws_ecr_repository_policy" "main" {
  count      = var.allow_cross_account_pull ? 1 : 0
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = var.allowed_account_ids
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
