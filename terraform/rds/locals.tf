# Local Variables

locals {
  # Common naming prefix
  name_prefix = "${var.environment}-${var.identifier}"

  # Required tags for governance
  required_tags = {
    Owner       = "platform-team@ryuqqq.com"
    CostCenter  = "engineering"
    Environment = var.environment
    Lifecycle   = "production"
    DataClass   = "sensitive"
    Service     = "shared-database"
    ManagedBy   = "Terraform"
    Stack       = "rds"
  }

  # Merge required tags with custom tags
  common_tags = merge(local.required_tags, var.tags)

  # Final snapshot identifier
  final_snapshot_identifier = var.final_snapshot_identifier != null ? var.final_snapshot_identifier : "${local.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
}
