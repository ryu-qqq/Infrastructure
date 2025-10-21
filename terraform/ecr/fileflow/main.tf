# ECR Repository for FileFlow Application

# ECR Repository
resource "aws_ecr_repository" "fileflow" {
  name                 = local.repository_name
  image_tag_mutability = var.image_tag_mutability

  # Enable image scanning on push for security
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  # Encryption configuration using KMS
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = data.aws_ssm_parameter.ecs-secrets-key-arn.value
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "ecr-${local.repository_name}"
      Component = "container-registry"
    }
  )
}

# Lifecycle Policy to manage image retention
resource "aws_ecr_lifecycle_policy" "fileflow" {
  repository = aws_ecr_repository.fileflow.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.lifecycle_policy_max_image_count} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.lifecycle_policy_max_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Repository Policy for cross-account access (if needed)
resource "aws_ecr_repository_policy" "fileflow" {
  repository = aws_ecr_repository.fileflow.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          ]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
      }
    ]
  })
}
