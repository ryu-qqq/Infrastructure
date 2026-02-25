# Provider Configuration for Central Logging System

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    opensearch = {
      source  = "opensearch-project/opensearch"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "prod-connectly"
    key            = "environments/prod/logging/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "prod-connectly-tf-lock"
    encrypt        = true
    kms_key_id     = "086b1677-614f-46ba-863e-23c215fb5010"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Module    = "logging"
    }
  }
}

# OpenSearch Provider for ISM policy management
# Uses the OpenSearch domain endpoint with AWS IAM authentication
provider "opensearch" {
  url         = "https://${aws_opensearch_domain.logs.endpoint}"
  healthcheck = false
  aws_region  = var.aws_region
  sign_aws_requests = true
}
