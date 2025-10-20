terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "s3" {
    # Backend configuration provided via CLI or backend config file
    # -backend-config="bucket=prod-connectly"
    # -backend-config="key=fileflow/terraform.tfstate"
    # -backend-config="region=ap-northeast-2"
    # -backend-config="dynamodb_table=prod-connectly-tf-lock"
  }
}
