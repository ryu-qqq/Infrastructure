# Terraform and Provider Configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration should be provided via backend config file or CLI
  # Example: terraform init -backend-config=backend.conf
  # See backend.conf.example for required configuration
  backend "s3" {
    key     = "monitoring/terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "infrastructure"
      Module    = "monitoring"
    }
  }
}
