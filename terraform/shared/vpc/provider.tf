# ============================================================================
# Terraform Backend Configuration
# ============================================================================

terraform {
  backend "s3" {
    bucket         = "prod-connectly"
    key            = "shared/network/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "prod-connectly-tf-lock"
    encrypt        = true
  }
}

# ============================================================================
# AWS Provider Configuration
# ============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = var.project_name
    }
  }
}
