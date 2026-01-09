# ============================================================================
# Stage RDS Configuration
# ============================================================================

# General
aws_region  = "ap-northeast-2"
environment = "staging"

# Tagging
service_name = "shared-database"
team         = "platform-team"
owner        = "fbtkdals2@naver.com"
cost_center  = "engineering"
project      = "shared-infrastructure"
data_class   = "internal" # Staging uses internal, not confidential

# Network Configuration
# Using same VPC as prod (prod-server-vpc) for simplicity
# Stage RDS is isolated by Security Group
vpc_id = "vpc-0f162b9e588276e09" # prod-server-vpc
private_subnet_ids = [
  "subnet-09692620519f86cf0", # prod-private-subnet-1 (ap-northeast-2a)
  "subnet-0d99080cbe134b6e9"  # prod-private-subnet-2 (ap-northeast-2b)
]

# Security Configuration
allowed_security_group_ids = [] # Add ECS task security groups as needed
allowed_cidr_blocks        = [] # Add CIDR blocks as needed

# RDS Configuration
identifier     = "shared-mysql"
mysql_version  = "8.0.44"
instance_class = "db.t4g.micro" # Smaller instance for staging

# Storage Configuration (must match prod snapshot: 200GB)
allocated_storage     = 200
max_allocated_storage = 500
storage_type          = "gp3"
storage_encrypted     = true

# ============================================================================
# Snapshot Restore Configuration
# ============================================================================
#
# For initial deployment from prod snapshot:
#   restore_from_snapshot = true
#   snapshot_identifier   = null  # Uses latest prod snapshot
#
# For fresh database (no prod data):
#   restore_from_snapshot = false
#   snapshot_identifier   = null
#
# For specific snapshot restore:
#   restore_from_snapshot = true
#   snapshot_identifier   = "rds:prod-shared-mysql-2025-01-07-backup"
#
restore_from_snapshot = true # Restore from prod snapshot
snapshot_identifier   = null  # Or specify exact snapshot ID

# Database Configuration
database_name   = "shared_db"
master_username = "admin"
port            = 3306

# High Availability (disabled for staging)
enable_multi_az = false

# Backup Configuration (reduced for staging)
backup_retention_period   = 7
backup_window             = "03:00-04:00"
maintenance_window        = "mon:04:00-mon:05:00"
skip_final_snapshot       = true # Allow easy teardown for staging
final_snapshot_identifier = null
copy_tags_to_snapshot     = true

# Monitoring Configuration
enable_performance_insights           = false # db.t4g.micro doesn't support Performance Insights
performance_insights_retention_period = 7
enable_enhanced_monitoring            = true
monitoring_interval                   = 60
enabled_cloudwatch_logs_exports       = ["error", "slowquery"]

# Security Configuration (relaxed for staging)
enable_deletion_protection          = false # Allow easy refresh
publicly_accessible                 = false
iam_database_authentication_enabled = false

# Parameter Group
parameter_group_family = "mysql8.0"
parameters = [
  {
    name  = "character_set_server"
    value = "utf8mb4"
  },
  {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  },
  {
    name  = "max_connections"
    value = "100" # Reduced for staging
  },
  {
    name  = "innodb_buffer_pool_size"
    value = "{DBInstanceClassMemory*3/4}"
  },
  {
    name  = "slow_query_log"
    value = "1"
  },
  {
    name  = "long_query_time"
    value = "2"
  },
  {
    name  = "log_queries_not_using_indexes"
    value = "1"
  }
]

# Alarms (disabled for staging)
enable_cloudwatch_alarms = false

# Secrets Rotation (disabled for staging)
enable_secrets_rotation = false

# RDS Proxy (disabled for staging)
enable_rds_proxy = false

# Additional Tags
tags = {
  Purpose      = "Staging environment for pre-production testing"
  RefreshCycle = "Monthly"
}
