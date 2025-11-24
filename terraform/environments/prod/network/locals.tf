# Local Values

locals {
  # Common naming prefix
  name_prefix = "${var.environment}-${var.service_name}"

  # Common tags (without Service tag, as it's a variable now)
  common_tags = {
    Environment = var.environment
  }
}
