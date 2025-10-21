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
    key            = "ecr/fileflow/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "prod-connectly-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "FileFlow"
      ManagedBy  = "Terraform"
      Repository = "infrastructure"
      Component  = "ecr"
    }
  }
}
