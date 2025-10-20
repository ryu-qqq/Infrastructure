# Shared MySQL RDS Configuration
# This file is auto-loaded by Terraform and committed to git
# Only non-sensitive values should be included here

# ============================================================================
# General Configuration
# ============================================================================

aws_region  = "ap-northeast-2"
environment = "prod"

# ============================================================================
# Network Configuration
# ============================================================================

vpc_id = "vpc-0f162b9e588276e09" # prod-server-vpc

private_subnet_ids = [
  "subnet-09692620519f86cf0", # prod-private-subnet-1 (ap-northeast-2a)
  "subnet-0d99080cbe134b6e9"  # prod-private-subnet-2 (ap-northeast-2b)
]

# ============================================================================
# Security Configuration
# ============================================================================

# 허용할 보안 그룹 ID 목록 (예: ECS 태스크, EC2 인스턴스)
# ECS 개발 완료 후 보안 그룹 ID를 추가하세요
allowed_security_group_ids = [
  # "sg-xxxxxxxxxxxxx"  # ECS tasks security group (나중에 추가)
]

# 허용할 CIDR 블록
# VPC 내부 모든 리소스에서 접근 가능 (개발/테스트용)
# 운영 환경에서는 특정 보안 그룹만 허용하는 것을 권장
allowed_cidr_blocks = [
  "10.0.0.0/16" # VPC CIDR - VPC 내부 모든 트래픽 허용
]

# ============================================================================
# RDS Configuration (운영용 스펙)
# ============================================================================

identifier     = "shared-mysql"
mysql_version  = "8.0.42" # Auto-upgraded by AWS
instance_class = "db.t4g.small" # 2 vCPU, 2GB RAM

# ============================================================================
# Storage Configuration
# ============================================================================

allocated_storage     = 30  # 초기 30GB
max_allocated_storage = 200 # 최대 200GB까지 자동 확장
storage_type          = "gp3"

# ============================================================================
# Database Configuration
# ============================================================================

database_name   = "shared_db"
master_username = "admin"
port            = 3306

# ============================================================================
# High Availability Configuration
# ============================================================================

enable_multi_az = true # Multi-AZ 활성화 (운영 환경)

# ============================================================================
# Backup Configuration
# ============================================================================

backup_retention_period = 14                    # 14일 백업 보존
backup_window           = "03:00-04:00"         # UTC 기준 (KST 12:00-13:00)
maintenance_window      = "mon:04:00-mon:05:00" # UTC 기준 (KST 월요일 13:00-14:00)
skip_final_snapshot     = false                 # 삭제 시 최종 스냅샷 생성
copy_tags_to_snapshot   = true

# ============================================================================
# Monitoring Configuration
# ============================================================================

enable_performance_insights           = false # Not supported on db.t4g.small
performance_insights_retention_period = 7     # 7일 보존

enable_enhanced_monitoring = true
monitoring_interval        = 60 # 60초 간격

enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

# ============================================================================
# Security Configuration
# ============================================================================

enable_deletion_protection = true  # 실수로 삭제 방지
publicly_accessible        = false # 퍼블릭 접근 불가
storage_encrypted          = true  # 스토리지 암호화

# ============================================================================
# Parameter Group Configuration
# ============================================================================

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
    value = "200"
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

# ============================================================================
# CloudWatch Alarms Configuration
# ============================================================================

enable_cloudwatch_alarms = true

cpu_utilization_threshold      = 80
free_storage_threshold         = 5368709120 # 5GB
freeable_memory_threshold      = 268435456  # 256MB
database_connections_threshold = 180        # 90% of max_connections (200)

# ============================================================================
# Additional Tags
# ============================================================================

tags = {
  Project     = "shared-infrastructure"
  Description = "Shared MySQL database for multiple services"
}
