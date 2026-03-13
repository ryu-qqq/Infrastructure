# ========================================
# Terraform Provider Configuration
# ========================================
# CloudFront for Host-Based API Routing (Stage)
# - stage.set-of.com → /* → Frontend ALB, /api/v1/* → Gateway ALB
# - stage-admin.set-of.com → /* → Gateway ALB
# ========================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "stage-connectly"
    key            = "environments/stage/cloudfront-routing/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "stage-connectly-tf-lock"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:ap-northeast-2:646886795421:key/a1169c88-95c9-4906-9a66-c15a1ab3c5ef"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "infrastructure"
    }
  }
}

# CloudFront requires ACM certificates in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "infrastructure"
    }
  }
}
