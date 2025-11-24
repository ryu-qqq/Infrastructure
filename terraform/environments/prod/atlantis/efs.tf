# EFS File System for Atlantis persistent storage
# Note: EFS resources kept as raw resources (no module available)

# Security Group for EFS
module "atlantis_efs_sg" {
  source = "../../../modules/security-group"

  name        = "atlantis-efs-${var.environment}"
  description = "Security group for Atlantis EFS mount targets"
  vpc_id      = var.vpc_id

  ingress_rules = [
    {
      description     = "NFS from ECS tasks"
      from_port       = 2049
      to_port         = 2049
      protocol        = "tcp"
      security_groups = [module.atlantis_ecs_tasks_sg.security_group_id]
    }
  ]

  egress_rules = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  # Tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center

  additional_tags = {
    Component   = "atlantis"
    Description = "Security group for Atlantis EFS mount targets"
  }
}

# EFS File System
resource "aws_efs_file_system" "atlantis" {
  creation_token = "atlantis-${var.environment}"
  encrypted      = true
  # TODO: Re-enable KMS encryption after EFS is created successfully
  # kms_key_id     = aws_kms_key.efs.arn

  # Performance settings
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  # Lifecycle policy - transition to IA after 30 days
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  # Backup policy
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "atlantis-${var.environment}"
      Component   = "atlantis"
      Description = "EFS file system for Atlantis persistent data storage"
    }
  )
}

# EFS Mount Targets (one per private subnet for HA)
resource "aws_efs_mount_target" "atlantis" {
  count = length(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.atlantis.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [module.atlantis_efs_sg.security_group_id]
}

# EFS Access Point for Atlantis
# Enforces POSIX user/group and root directory
resource "aws_efs_access_point" "atlantis" {
  file_system_id = aws_efs_file_system.atlantis.id

  # Root directory for Atlantis data
  root_directory {
    path = "/atlantis-data"

    creation_info {
      owner_gid   = 100 # atlantis user group
      owner_uid   = 100 # atlantis user
      permissions = "755"
    }
  }

  # POSIX user for file operations
  posix_user {
    gid = 100
    uid = 100
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "atlantis-${var.environment}"
      Component   = "atlantis"
      Description = "EFS access point for Atlantis data directory"
    }
  )
}

# Outputs
output "atlantis_efs_id" {
  description = "The ID of the Atlantis EFS file system"
  value       = aws_efs_file_system.atlantis.id
}

output "atlantis_efs_arn" {
  description = "The ARN of the Atlantis EFS file system"
  value       = aws_efs_file_system.atlantis.arn
}

output "atlantis_efs_dns_name" {
  description = "The DNS name of the Atlantis EFS file system"
  value       = aws_efs_file_system.atlantis.dns_name
}

output "atlantis_efs_access_point_id" {
  description = "The ID of the Atlantis EFS access point"
  value       = aws_efs_access_point.atlantis.id
}

output "atlantis_efs_access_point_arn" {
  description = "The ARN of the Atlantis EFS access point"
  value       = aws_efs_access_point.atlantis.arn
}
