# KMS Keys for Common Platform Infrastructure
# Following governance standards for data-class based key separation

# ============================================================================
# 1. Terraform State Encryption Key (Highest Priority)
# ============================================================================

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state file encryption in S3"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = merge(
    local.required_tags,
    {
      Name      = "terraform-state"
      DataClass = "confidential"
      Component = "terraform-backend"
    }
  )
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# ============================================================================
# 2. RDS Encryption Key (Future-ready)
# ============================================================================

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS instance encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = merge(
    local.required_tags,
    {
      Name      = "rds-encryption"
      DataClass = "highly-confidential"
      Component = "database"
    }
  )
}

resource "aws_kms_alias" "rds" {
  name          = "alias/rds-encryption"
  target_key_id = aws_kms_key.rds.key_id
}

# ============================================================================
# 3. ECS Secrets Encryption Key (Short-term Priority)
# ============================================================================

resource "aws_kms_key" "ecs_secrets" {
  description             = "KMS key for ECS task secrets and environment variables encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = merge(
    local.required_tags,
    {
      Name      = "ecs-secrets"
      DataClass = "confidential"
      Component = "ecs"
    }
  )
}

resource "aws_kms_alias" "ecs_secrets" {
  name          = "alias/ecs-secrets"
  target_key_id = aws_kms_key.ecs_secrets.key_id
}

# ============================================================================
# 4. Secrets Manager Encryption Key (Short-term Priority)
# ============================================================================

resource "aws_kms_key" "secrets_manager" {
  description             = "KMS key for AWS Secrets Manager encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = merge(
    local.required_tags,
    {
      Name      = "secrets-manager"
      DataClass = "highly-confidential"
      Component = "secrets-manager"
    }
  )
}

resource "aws_kms_alias" "secrets_manager" {
  name          = "alias/secrets-manager"
  target_key_id = aws_kms_key.secrets_manager.key_id
}
