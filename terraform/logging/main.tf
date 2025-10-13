# Central Logging System
# CloudWatch Log Groups for centralized log collection
# IN-116: Central logging system setup

# ============================================================================
# Common Tags
# ============================================================================

module "common_tags" {
  source = "../modules/common-tags"

  environment = var.environment
  service     = "logging"
  team        = "platform-team"
  owner       = var.owner
  cost_center = var.cost_center
}

# ============================================================================
# KMS Key Reference from Remote State
# ============================================================================

data "terraform_remote_state" "kms" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "kms/terraform.tfstate"
    region = var.aws_region
  }
}

# ============================================================================
# ECS Service Log Groups
# ============================================================================

# Atlantis Application Logs
module "atlantis_application_logs" {
  source = "../modules/cloudwatch-log-group"

  name              = "/aws/ecs/atlantis/application"
  retention_in_days = 14
  kms_key_id        = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn
  log_type          = "application"
  common_tags       = module.common_tags.tags
}

# Atlantis Error Logs (Future Sentry integration)
module "atlantis_error_logs" {
  source = "../modules/cloudwatch-log-group"

  name              = "/aws/ecs/atlantis/errors"
  retention_in_days = 90
  kms_key_id        = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn
  log_type          = "errors"
  common_tags       = module.common_tags.tags

  # Sentry integration (future)
  sentry_sync_status       = "pending"
  enable_error_rate_metric = true
  metric_namespace         = "CustomLogs/Atlantis"
}

# ============================================================================
# Lambda Function Log Groups
# ============================================================================

# Secrets Manager Rotation Lambda Logs
# Note: This log group already exists, this is for management and consistency
module "secrets_rotation_logs" {
  source = "../modules/cloudwatch-log-group"

  name              = "/aws/lambda/secrets-manager-rotation"
  retention_in_days = 14
  kms_key_id        = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn
  log_type          = "application"
  common_tags       = module.common_tags.tags
}

# ============================================================================
# Future Service Log Groups (Commented out until services are created)
# ============================================================================

# API Server Log Groups (Future)
# module "api_application_logs" {
#   source = "../modules/cloudwatch-log-group"
#
#   name               = "/aws/ecs/api-server/application"
#   retention_in_days  = 14
#   kms_key_id         = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn
#   log_type           = "application"
#   common_tags        = module.common_tags.tags
# }
#
# module "api_error_logs" {
#   source = "../modules/cloudwatch-log-group"
#
#   name               = "/aws/ecs/api-server/errors"
#   retention_in_days  = 90
#   kms_key_id         = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn
#   log_type           = "errors"
#   common_tags        = module.common_tags.tags
#
#   sentry_sync_status       = "pending"
#   enable_error_rate_metric = true
#   metric_namespace         = "CustomLogs/APIServer"
# }
#
# module "api_llm_logs" {
#   source = "../modules/cloudwatch-log-group"
#
#   name               = "/aws/ecs/api-server/llm"
#   retention_in_days  = 60
#   kms_key_id         = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn
#   log_type           = "llm"
#   common_tags        = module.common_tags.tags
#
#   langfuse_sync_status = "pending"
# }
