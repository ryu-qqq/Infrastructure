locals {
  repository_name = "fileflow"

  required_tags = {
    Environment = var.environment
    Service     = "fileflow"
    Owner       = "platform-team"
    CostCenter  = "engineering"
    Lifecycle   = "critical"
    DataClass   = "public"
  }
}
