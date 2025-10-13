# Terraform Provider Configuration for Bootstrap Module
#
# This module uses a LOCAL backend because it creates the S3/DynamoDB resources
# that other modules depend on for remote state storage (chicken-egg problem).
#
# After creating these resources, other modules can use them as remote backend.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local backend - state file stored locally
  # DO NOT change this to S3 backend
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "infrastructure"
      Module    = "bootstrap"
    }
  }
}
