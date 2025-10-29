# Local Variables

locals {
  # Common naming prefix
  name_prefix = "${var.environment}-${var.identifier}"

  # Required tags for governance (includes optional tags)
  required_tags = merge(
    {
      Environment = var.environment
      Service     = "shared-database"
      Team        = "platform-team"
      Owner       = "fbtkdals2@naver.com"
      CostCenter  = "engineering"
      ManagedBy   = "Terraform"
      Project     = "shared-infrastructure"
      # Optional tags
      Lifecycle = "production"
      DataClass = "sensitive"
      Stack     = "rds"
    },
    var.tags
  )

  # Final snapshot identifier
  final_snapshot_identifier = var.final_snapshot_identifier != null ? var.final_snapshot_identifier : "${local.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
}
