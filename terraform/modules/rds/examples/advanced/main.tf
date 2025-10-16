# Advanced Example - Production-Ready RDS Configuration
#
# This example demonstrates a full-featured production-ready RDS setup with:
# - KMS encryption
# - Multi-AZ deployment
# - Enhanced backup configuration
# - Performance Insights
# - Enhanced Monitoring
# - Custom parameter group

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Type = "private"
  }
}

# Required Tags for Governance
locals {
  required_tags = {
    Environment = var.environment
    Service     = var.service_name
    Team        = "platform-team"
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
    Project     = "rds-module-advanced-example"
  }
}

# KMS Key for RDS Encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption - ${var.service_name} ${var.environment}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name = "${var.service_name}-rds-key-${var.environment}"
    }
  )
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.service_name}-rds-${var.environment}"
  target_key_id = aws_kms_key.rds.key_id
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.service_name}-rds-${var.environment}"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from application layer"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  tags = merge(
    local.required_tags,
    {
      Name = "${var.service_name}-rds-${var.environment}"
    }
  )
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.service_name}-rds-monitoring-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = merge(
    local.required_tags,
    {
      Name = "${var.service_name}-rds-monitoring-${var.environment}"
    }
  )
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS Module - Production PostgreSQL with Full Features
module "rds_postgres" {
  source = "../../"

  # Database Configuration
  identifier            = "${var.service_name}-postgres-${var.environment}"
  engine                = "postgres"
  engine_version        = "15.4"
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  # Storage Configuration
  storage_type       = "gp3"
  storage_throughput = 250
  storage_encrypted  = true
  kms_key_id         = aws_kms_key.rds.arn

  # Database Credentials
  db_name         = var.db_name
  master_username = var.master_username
  master_password = var.master_password

  # Network Configuration
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible = false

  # High Availability
  multi_az = var.multi_az

  # Backup Configuration
  backup_retention_period = 14
  backup_window           = "03:00-04:00"
  skip_final_snapshot     = false
  copy_tags_to_snapshot   = true

  # Maintenance Configuration
  auto_minor_version_upgrade = true
  maintenance_window         = "sun:04:00-sun:05:00"

  # Parameter Group with Custom Settings
  parameter_group_family = "postgres15"
  parameters = [
    {
      name  = "max_connections"
      value = "200"
    },
    {
      name  = "shared_buffers"
      value = "{DBInstanceClassMemory/32768}"
    },
    {
      name  = "effective_cache_size"
      value = "{DBInstanceClassMemory/16384}"
    },
    {
      name  = "maintenance_work_mem"
      value = "2097152"
    },
    {
      name  = "checkpoint_completion_target"
      value = "0.9"
    },
    {
      name  = "wal_buffers"
      value = "16384"
    },
    {
      name  = "default_statistics_target"
      value = "100"
    },
    {
      name  = "random_page_cost"
      value = "1.1"
    },
    {
      name  = "effective_io_concurrency"
      value = "200"
    },
    {
      name  = "work_mem"
      value = "10485"
    }
  ]

  # Monitoring Configuration
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn

  # Deletion Protection
  deletion_protection = var.deletion_protection

  # Tags
  common_tags = local.required_tags
}

# Outputs
output "db_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = module.rds_postgres.db_instance_endpoint
}

output "db_address" {
  description = "The hostname of the RDS instance"
  value       = module.rds_postgres.db_instance_address
}

output "db_port" {
  description = "The port on which the DB accepts connections"
  value       = module.rds_postgres.db_instance_port
}

output "db_instance_id" {
  description = "The identifier of the RDS instance"
  value       = module.rds_postgres.db_instance_id
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = module.rds_postgres.db_instance_arn
}

output "db_instance_resource_id" {
  description = "The RDS Resource ID (for Performance Insights)"
  value       = module.rds_postgres.db_instance_resource_id
}

output "kms_key_id" {
  description = "The KMS key ID used for encryption"
  value       = aws_kms_key.rds.id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = aws_kms_key.rds.arn
}

output "monitoring_role_arn" {
  description = "The ARN of the monitoring IAM role"
  value       = aws_iam_role.rds_monitoring.arn
}
