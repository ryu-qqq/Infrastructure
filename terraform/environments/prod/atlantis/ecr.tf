# ECR Repository for Atlantis Docker Images using module

module "atlantis_ecr" {
  source = "../../../modules/ecr"

  name                 = "atlantis"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  kms_key_arn          = aws_kms_key.ecr.arn

  # Lifecycle policy configuration
  enable_lifecycle_policy      = true
  max_image_count              = 10
  lifecycle_tag_prefixes       = ["v"]
  untagged_image_expiry_days   = 7

  # Repository policy for access control
  repository_policy = jsonencode({
    Version = "2008-10-17"
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
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
      },
      {
        Sid    = "AllowECSTaskExecution"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })

  # Tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center

  additional_tags = {
    Component   = "atlantis"
    Description = "Docker images for Atlantis Terraform automation server"
  }
}

# Output the repository information
output "atlantis_ecr_repository_url" {
  description = "The URL of the Atlantis ECR repository"
  value       = module.atlantis_ecr.repository_url
}

output "atlantis_ecr_repository_arn" {
  description = "The ARN of the Atlantis ECR repository"
  value       = module.atlantis_ecr.repository_arn
}
