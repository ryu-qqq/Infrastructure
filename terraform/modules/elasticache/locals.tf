# ==============================================================================
# Local Values
# ==============================================================================

locals {
  # Determine port based on engine type if not explicitly provided
  port = coalesce(var.port, var.engine == "redis" ? 6379 : 11211)
}
