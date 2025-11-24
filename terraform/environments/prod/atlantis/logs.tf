# CloudWatch Log Group for Atlantis using module

module "atlantis_logs" {
  source = "../../../modules/cloudwatch-log-group"

  name              = "/aws/ecs/atlantis-${var.environment}/application"
  retention_in_days = 7
  kms_key_id        = null # Using default AWS managed encryption

  # Tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center

  additional_tags = {
    Component   = "atlantis"
    Description = "CloudWatch log group for Atlantis ECS tasks"
  }
}

# Output
output "atlantis_cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group for Atlantis"
  value       = module.atlantis_logs.log_group_name
}

output "atlantis_cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch log group for Atlantis"
  value       = module.atlantis_logs.log_group_arn
}
