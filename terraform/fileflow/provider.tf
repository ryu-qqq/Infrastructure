provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Stack       = "fileflow"
      Environment = var.environment
    }
  }
}
