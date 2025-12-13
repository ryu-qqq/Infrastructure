# RDS PostgreSQL for n8n using module

# =============================================================================
# RDS Security Group
# =============================================================================

module "n8n_rds_sg" {
  source = "../../../modules/security-group"

  name        = "${local.name_prefix}-rds"
  description = "Security group for n8n RDS PostgreSQL"
  vpc_id      = var.vpc_id
  type        = "custom"

  # Allow PostgreSQL access from ECS tasks
  custom_ingress_rules = [
    {
      description              = "Allow PostgreSQL access from n8n ECS tasks"
      from_port                = local.db_port
      to_port                  = local.db_port
      protocol                 = "tcp"
      source_security_group_id = module.n8n_ecs_tasks_sg.security_group_id
    }
  ]

  # No egress needed for RDS
  enable_default_egress = false

  # Tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center

  additional_tags = {
    Component   = "n8n"
    Description = "Security group for n8n RDS PostgreSQL"
  }
}

# =============================================================================
# RDS PostgreSQL
# =============================================================================

module "n8n_rds" {
  source = "../../../modules/rds"

  # Instance Configuration
  identifier     = "${local.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  # Database Configuration
  db_name         = local.db_name
  master_username = local.db_username
  master_password = random_password.db-password.result
  port            = local.db_port

  # Storage Configuration
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Network Configuration
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [module.n8n_rds_sg.security_group_id]
  publicly_accessible = false
  multi_az            = var.db_multi_az

  # Backup Configuration
  backup_retention_period   = var.db_backup_retention_period
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name_prefix}-final-snapshot"
  copy_tags_to_snapshot     = true

  # Performance & Monitoring
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql"]

  # Parameter Group
  parameter_group_family = "postgres15"
  parameters = [
    {
      name  = "log_statement"
      value = "all"
    },
    {
      name  = "log_min_duration_statement"
      value = "1000"
    }
  ]

  # Protection
  deletion_protection = true
  apply_immediately   = false

  # Tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center

  additional_tags = {
    Component   = "n8n"
    Description = "PostgreSQL database for n8n workflow automation"
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = module.n8n_rds.db_instance_endpoint
}

output "rds_port" {
  description = "The port the RDS instance is listening on"
  value       = module.n8n_rds.db_instance_port
}

output "rds_database_name" {
  description = "The name of the default database"
  value       = local.db_name
}

output "rds_security_group_id" {
  description = "The ID of the RDS security group"
  value       = module.n8n_rds_sg.security_group_id
}
