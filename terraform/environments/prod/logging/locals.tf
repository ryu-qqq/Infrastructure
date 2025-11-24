# Central Logging System - Local Variables
# Defines common values used across all CloudWatch Log Groups

locals {
  # Common configuration
  kms_key_arn = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn

  # Common tags for all resources
  common_tags = {
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    Environment = var.environment
  }
}
