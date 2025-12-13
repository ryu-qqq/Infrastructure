# Local Values for Service Discovery

locals {
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.lifecycle_stage
    DataClass   = var.data_class
    Service     = var.service_name
    Team        = var.team
    ManagedBy   = "terraform"
    Project     = var.project
  }
}
