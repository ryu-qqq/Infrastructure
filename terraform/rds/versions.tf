terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }

  backend "s3" {
    bucket  = "ryuqqq-prod-tfstate"
    key     = "rds/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
  }
}
