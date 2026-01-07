# Local Variables

locals {
  # Common naming prefix
  name_prefix = "${var.environment}-${var.identifier}"

  # Final snapshot identifier
  final_snapshot_identifier = var.final_snapshot_identifier != null ? var.final_snapshot_identifier : "${local.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Required tags for all resources
  required_tags = {
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "Terraform"
    Project     = var.project
    DataClass   = var.data_class
    Stack       = "rds"
  }
}
