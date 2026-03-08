provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "shared"
      Service     = "dms-replication"
      Team        = "platform-team"
      Owner       = "fbtkdals2@naver.com"
      CostCenter  = "engineering"
      ManagedBy   = "Terraform"
      Project     = "shared-infrastructure"
      DataClass   = "confidential"
      Stack       = "dms"
    }
  }
}
