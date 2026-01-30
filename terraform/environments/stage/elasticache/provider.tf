provider "aws" {
  region = var.aws_region

  # Zero-Tolerance: 모든 필수 태그를 provider 수준에서 적용
  default_tags {
    tags = {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "elasticache"
    }
  }
}
