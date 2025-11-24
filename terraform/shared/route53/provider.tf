# ============================================================================
# Terraform Backend and Provider Configuration
# ============================================================================

# Backend configuration
terraform {
  backend "s3" {
    bucket         = "prod-connectly"
    key            = "shared/route53/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "prod-connectly-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  skip_requesting_account_id = true

  # Import 시 태그 권한 문제로 인해 default_tags 비활성화
  # default_tags {
  #   tags = {
  #     ManagedBy = "terraform"
  #     Project   = var.project_name
  #   }
  # }
}
