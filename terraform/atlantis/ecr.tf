# ECR Repository for Atlantis Docker Images

resource "aws_ecr_repository" "atlantis" {
  name                 = "atlantis"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "atlantis"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "infrastructure"
    Component   = "atlantis"
    Description = "Docker images for Atlantis Terraform automation server"
  }
}

# Lifecycle policy to manage image retention
resource "aws_ecr_lifecycle_policy" "atlantis" {
  repository = aws_ecr_repository.atlantis.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 7 days"
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

# Output the repository URL for use in other configurations
output "atlantis_ecr_repository_url" {
  description = "The URL of the Atlantis ECR repository"
  value       = aws_ecr_repository.atlantis.repository_url
}

output "atlantis_ecr_repository_arn" {
  description = "The ARN of the Atlantis ECR repository"
  value       = aws_ecr_repository.atlantis.arn
}
