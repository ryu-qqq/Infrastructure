# ============================================================================
# DMS Replication Configuration: Prod → Stage (luxurydb)
# ============================================================================

# Network (same VPC: prod-server-vpc)
vpc_id = "vpc-0f162b9e588276e09"
private_subnet_ids = [
  "subnet-09692620519f86cf0", # prod-private-subnet-1 (ap-northeast-2a)
  "subnet-0d99080cbe134b6e9"  # prod-private-subnet-2 (ap-northeast-2b)
]

# Source: Prod RDS (DMS 전용 유저 사용)
source_db_host             = "prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com"
source_db_port             = 3306
source_db_name             = "shared_db"
source_secrets_manager_arn = "arn:aws:secretsmanager:ap-northeast-2:646886795421:secret:prod-shared-mysql-dms-o0KRmq"

# Target: Stage RDS (direct endpoint - DMS는 Proxy 미지원)
target_db_host             = "staging-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com"
target_db_port             = 3306
target_db_name             = "shared_db"
target_secrets_manager_arn = "arn:aws:secretsmanager:ap-northeast-2:646886795421:secret:staging-shared-mysql-dms-JERewT"

# Security Groups
source_security_group_id = "sg-0d9b6f65239b16b44" # prod-shared-mysql-sg
target_security_group_id = "sg-037a83859fadc008e" # staging-shared-mysql-sg

# Schema to replicate
schema_name    = "luxurydb"
migration_type = "full-load-and-cdc"

# DMS Instance
replication_instance_class = "dms.t3.medium"
allocated_storage          = 50
