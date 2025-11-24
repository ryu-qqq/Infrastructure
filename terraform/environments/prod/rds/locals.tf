# Local Variables

locals {
  # Common naming prefix
  name_prefix = "${var.environment}-${var.identifier}"

  # Final snapshot identifier
  final_snapshot_identifier = var.final_snapshot_identifier != null ? var.final_snapshot_identifier : "${local.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
}
