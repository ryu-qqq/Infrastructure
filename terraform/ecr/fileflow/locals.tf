# Local Variables

locals {
  # Required tags for all resources
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.lifecycle_stage
    DataClass   = var.data_class
    Service     = "fileflow"
  }

  # ECR repository name
  repository_name = "fileflow"
}
