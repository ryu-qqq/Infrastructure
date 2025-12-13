# CloudWatch Logs for n8n using module

module "n8n_logs" {
  source = "../../../modules/cloudwatch-log-group"

  name              = "/aws/ecs/n8n-${var.environment}"
  retention_in_days = 30

  # Tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center

  additional_tags = {
    Component   = "n8n"
    Description = "CloudWatch Logs for n8n workflow automation"
  }
}

# Outputs
output "log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = module.n8n_logs.log_group_name
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group"
  value       = module.n8n_logs.log_group_arn
}
