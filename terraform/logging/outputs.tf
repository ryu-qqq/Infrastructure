# Central Logging System Outputs

# ============================================================================
# Atlantis Log Groups
# ============================================================================

output "atlantis_application_log_group" {
  description = "Atlantis application log group details"
  value = {
    name              = module.atlantis_application_logs.log_group_name
    arn               = module.atlantis_application_logs.log_group_arn
    retention_in_days = module.atlantis_application_logs.retention_in_days
  }
}

output "atlantis_error_log_group" {
  description = "Atlantis error log group details"
  value = {
    name              = module.atlantis_error_logs.log_group_name
    arn               = module.atlantis_error_logs.log_group_arn
    retention_in_days = module.atlantis_error_logs.retention_in_days
  }
}

# ============================================================================
# Lambda Log Groups
# ============================================================================

output "secrets_rotation_log_group" {
  description = "Secrets Manager rotation Lambda log group details"
  value = {
    name              = module.secrets_rotation_logs.log_group_name
    arn               = module.secrets_rotation_logs.log_group_arn
    retention_in_days = module.secrets_rotation_logs.retention_in_days
  }
}

# ============================================================================
# Summary
# ============================================================================

output "log_groups_summary" {
  description = "Summary of all created log groups"
  value = {
    total_groups = 3
    groups = [
      {
        name      = module.atlantis_application_logs.log_group_name
        type      = "application"
        retention = module.atlantis_application_logs.retention_in_days
      },
      {
        name      = module.atlantis_error_logs.log_group_name
        type      = "errors"
        retention = module.atlantis_error_logs.retention_in_days
      },
      {
        name      = module.secrets_rotation_logs.log_group_name
        type      = "application"
        retention = module.secrets_rotation_logs.retention_in_days
      }
    ]
  }
}

output "kms_key_used" {
  description = "KMS key used for log encryption"
  value = {
    arn   = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn
    alias = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_alias
  }
}
