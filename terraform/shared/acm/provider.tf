# ============================================================================
# Terraform Backend and Provider Configuration
# ============================================================================

# Backend configuration
terraform {
  backend "s3" {
    bucket         = "prod-connectly"
    key            = "shared/acm/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "prod-connectly-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = var.project_name
    }
  }
}
