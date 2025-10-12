# Atlantis Terraform Configuration Variables
# This file is auto-loaded by Terraform and committed to git
# Only non-sensitive values should be included here

# Environment
environment = "prod"
aws_region  = "ap-northeast-2"

# ACM Certificate ARN for HTTPS
# Certificate: *.set-of.com (AWS-issued, auto-renewable)
# Status: ISSUED
# Valid until: 2026-09-05
acm_certificate_arn = "arn:aws:acm:ap-northeast-2:646886795421:certificate/695d4642-371c-4d49-b442-af89992ffbd5"

# Atlantis Configuration
atlantis_url            = "https://atlantis.set-of.com"
atlantis_repo_allowlist = "github.com/ryu-qqq/*"

# Network Configuration
vpc_id = "vpc-0f162b9e588276e09" # prod-server-vpc
public_subnet_ids = [
  "subnet-0bd2fc282b0fb137a", # prod-public-subnet-1 (ap-northeast-2a)
  "subnet-0c8c0ad85064b80bb"  # prod-public-subnet-2 (ap-northeast-2b)
]
private_subnet_ids = [
  "subnet-09692620519f86cf0", # prod-private-subnet-1 (ap-northeast-2a)
  "subnet-0d99080cbe134b6e9"  # prod-private-subnet-2 (ap-northeast-2b)
]

# Security - Allowed CIDR blocks for ALB access
allowed_cidr_blocks = [
  "0.0.0.0/0" # TODO: Restrict to specific IP ranges for production
]

# Resource Configuration
atlantis_cpu    = 512
atlantis_memory = 1024

# ALB Configuration
alb_enable_deletion_protection = false # Set to true for production
# Updated: Sat Oct 11 16:40:30 KST 2025
# Updated: Sun Oct 12 20:53:17 KST 2025
# Updated: Sun Oct 12 23:01:00 KST 2025 - New GitHub App configuration
