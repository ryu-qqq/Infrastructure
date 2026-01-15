# Terraform and Provider Configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "prod-connectly"
    key            = "environments/prod/cloudfront-redirect/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "prod-connectly-tf-lock"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:ap-northeast-2:646886795421:key/086b1677-614f-46ba-863e-23c215fb5010"
  }
}

# Default provider (ap-northeast-2)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Repository  = "infrastructure"
      Stack       = "cloudfront-redirect"
      Environment = var.environment
    }
  }
}

# US East 1 provider for ACM certificates (required for CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Repository  = "infrastructure"
      Stack       = "cloudfront-redirect"
      Environment = var.environment
    }
  }
}
