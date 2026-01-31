# Local values for n8n deployment

# Common Tags Module
module "tags" {
  source = "../../../modules/common-tags"

  environment = var.environment
  service     = var.service_name
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = "n8n"
  data_class  = var.data_class

  additional_tags = {
    Component = "n8n"
  }
}

locals {
  # Required tags for all resources
  required_tags = module.tags.tags

  # Naming convention
  name_prefix = "n8n-${var.environment}"

  # n8n container configuration
  n8n_container_name = "n8n"
  n8n_container_port = 5678

  # Database configuration (n8n)
  db_name     = "n8n"
  db_port     = 5432
  db_username = "n8nadmin"

  # Shared API/MCP database configuration
  # Note: Database and user must be created manually in PostgreSQL after apply
  shared_api_db_name     = "shared_api"
  shared_api_db_username = "shared_api_user"
}
