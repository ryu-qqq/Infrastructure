# Terraform and Provider Configuration

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "ryuqqq-prod-tfstate"
    key            = "ecr/fileflow/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
    kms_key_id     = "alias/terraform-state"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Module    = "ecr/fileflow"
    }
  }
}
