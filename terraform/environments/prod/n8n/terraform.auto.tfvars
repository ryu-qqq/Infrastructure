# n8n Terraform Configuration Variables
# This file is auto-loaded by Terraform and committed to git
# Only non-sensitive values should be included here

# Environment
environment = "prod"
aws_region  = "ap-northeast-2"

# Network Configuration (same as atlantis - prod VPC)
vpc_id = "vpc-0f162b9e588276e09" # prod-server-vpc
public_subnet_ids = [
  "subnet-0bd2fc282b0fb137a", # prod-public-subnet-1 (ap-northeast-2a)
  "subnet-0c8c0ad85064b80bb"  # prod-public-subnet-2 (ap-northeast-2b)
]
private_subnet_ids = [
  "subnet-09692620519f86cf0", # prod-private-subnet-1 (ap-northeast-2a)
  "subnet-0d99080cbe134b6e9"  # prod-private-subnet-2 (ap-northeast-2b)
]

# ACM Certificate ARN for HTTPS
# Certificate: *.set-of.com (AWS-issued, auto-renewable)
# Status: ISSUED
# Valid until: 2026-09-05
acm_certificate_arn = "arn:aws:acm:ap-northeast-2:646886795421:certificate/695d4642-371c-4d49-b442-af89992ffbd5"

# n8n Application Configuration
n8n_url = "https://n8n.set-of.com"

# ECS Task Configuration
n8n_cpu           = 1024
n8n_memory        = 2048
n8n_image_tag     = "latest"
n8n_desired_count = 1

# RDS Configuration
# Upgraded for shared usage (n8n, API, MCP)
db_instance_class          = "db.t4g.small"  # Graviton-based, cost-effective
db_allocated_storage       = 20
db_max_allocated_storage   = 100
db_multi_az                = true            # HA for production shared DB
db_backup_retention_period = 7

# ALB Configuration
allowed_cidr_blocks = [
  "0.0.0.0/0" # TODO: Restrict to specific IP ranges for production
]
alb_health_check_path          = "/healthz"
alb_enable_deletion_protection = false # Set to true for production

# Governance Tags
service_name = "n8n"
team         = "platform-team"
owner        = "platform-team"
cost_center  = "engineering"
data_class   = "confidential"
