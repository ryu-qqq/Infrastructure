# ECR Repository Module
# Creates an ECR repository with KMS encryption, image scanning, and lifecycle policies

# Common Tags Module
module "tags" {
  source = "../common-tags"

  environment = var.environment
  service     = var.service_name
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project
  data_class  = var.data_class

  additional_tags = var.additional_tags
}

locals {
  # Required tags for governance compliance
  required_tags = module.tags.tags
}

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn  # null이면 AWS 관리형 KMS 키 사용
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "ecr-${var.name}"
      Component = "container-registry"
    }
  )
}

# Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "this" {
  count      = var.enable_lifecycle_policy ? 1 : 0
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = var.lifecycle_tag_prefixes
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after ${var.untagged_image_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_expiry_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Repository Policy (optional)
resource "aws_ecr_repository_policy" "this" {
  count      = var.repository_policy != null ? 1 : 0
  repository = aws_ecr_repository.this.name
  policy     = var.repository_policy
}

# Default repository policy for same account access
resource "aws_ecr_repository_policy" "default" {
  count      = var.repository_policy == null && var.enable_default_policy ? 1 : 0
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# Data source for account ID
data "aws_caller_identity" "current" {}

# SSM Parameter for cross-stack reference (optional)
resource "aws_ssm_parameter" "repository-url" {
  count = var.create_ssm_parameter ? 1 : 0

  name        = "/shared/ecr/${var.name}-repository-url"
  type        = "String"
  value       = aws_ecr_repository.this.repository_url
  description = "ECR repository URL for ${var.name}"

  tags = local.required_tags
}
