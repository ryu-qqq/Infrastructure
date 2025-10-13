# Local Values

locals {
  # Required tags for governance compliance
  # Note: These tags are defined for imported existing resources
  # IMPORTANT: Actual resources have lifecycle { ignore_changes = [tags] }
  # to prevent modification of already-deployed infrastructure tags due to IAM permission constraints
  required_tags = {
    Owner       = "platform-team"  # Platform team manages shared infrastructure
    CostCenter  = "infrastructure" # Infrastructure cost center
    Lifecycle   = "production"     # Production environment
    DataClass   = "internal"       # Internal network infrastructure
    Service     = "network"        # Network infrastructure service
    Environment = var.environment
    Component   = "shared-infrastructure"
  }
}
