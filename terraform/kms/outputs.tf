# KMS Module Outputs

# ============================================================================
# Terraform State Key Outputs
# ============================================================================

output "terraform_state_key_id" {
  description = "The ID of the KMS key for Terraform state encryption"
  value       = aws_kms_key.terraform_state.key_id
}

output "terraform_state_key_arn" {
  description = "The ARN of the KMS key for Terraform state encryption"
  value       = aws_kms_key.terraform_state.arn
}

output "terraform_state_key_alias" {
  description = "The alias of the KMS key for Terraform state encryption"
  value       = aws_kms_alias.terraform_state.name
}

# ============================================================================
# RDS Key Outputs
# ============================================================================

output "rds_key_id" {
  description = "The ID of the KMS key for RDS encryption"
  value       = aws_kms_key.rds.key_id
}

output "rds_key_arn" {
  description = "The ARN of the KMS key for RDS encryption"
  value       = aws_kms_key.rds.arn
}

output "rds_key_alias" {
  description = "The alias of the KMS key for RDS encryption"
  value       = aws_kms_alias.rds.name
}

# ============================================================================
# ECS Secrets Key Outputs
# ============================================================================

output "ecs_secrets_key_id" {
  description = "The ID of the KMS key for ECS secrets encryption"
  value       = aws_kms_key.ecs_secrets.key_id
}

output "ecs_secrets_key_arn" {
  description = "The ARN of the KMS key for ECS secrets encryption"
  value       = aws_kms_key.ecs_secrets.arn
}

output "ecs_secrets_key_alias" {
  description = "The alias of the KMS key for ECS secrets encryption"
  value       = aws_kms_alias.ecs_secrets.name
}

# ============================================================================
# Secrets Manager Key Outputs
# ============================================================================

output "secrets_manager_key_id" {
  description = "The ID of the KMS key for Secrets Manager encryption"
  value       = aws_kms_key.secrets_manager.key_id
}

output "secrets_manager_key_arn" {
  description = "The ARN of the KMS key for Secrets Manager encryption"
  value       = aws_kms_key.secrets_manager.arn
}

output "secrets_manager_key_alias" {
  description = "The alias of the KMS key for Secrets Manager encryption"
  value       = aws_kms_alias.secrets_manager.name
}

# ============================================================================
# Summary Output
# ============================================================================

output "kms_keys_summary" {
  description = "Summary of all KMS keys created"
  value = {
    terraform_state = {
      key_id = aws_kms_key.terraform_state.key_id
      arn    = aws_kms_key.terraform_state.arn
      alias  = aws_kms_alias.terraform_state.name
    }
    rds = {
      key_id = aws_kms_key.rds.key_id
      arn    = aws_kms_key.rds.arn
      alias  = aws_kms_alias.rds.name
    }
    ecs_secrets = {
      key_id = aws_kms_key.ecs_secrets.key_id
      arn    = aws_kms_key.ecs_secrets.arn
      alias  = aws_kms_alias.ecs_secrets.name
    }
    secrets_manager = {
      key_id = aws_kms_key.secrets_manager.key_id
      arn    = aws_kms_key.secrets_manager.arn
      alias  = aws_kms_alias.secrets_manager.name
    }
  }
}
