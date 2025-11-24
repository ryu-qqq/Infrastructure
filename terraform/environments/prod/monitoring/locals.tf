# Local Variables for Monitoring Stack

locals {
  # Name prefix for resources
  name_prefix = "${var.environment}-${var.service}"

  # Required tags (Governance Standard)
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.resource_lifecycle
    DataClass   = var.data_class
    Service     = var.service
    Team        = var.team
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }

  # SNS topic names
  sns_topics = {
    critical = "${local.name_prefix}-critical"
    warning  = "${local.name_prefix}-warning"
    info     = "${local.name_prefix}-info"
  }

  # IAM role names
  iam_roles = {
    ecs_amp_writer     = "${local.name_prefix}-ecs-amp-writer"
    grafana_amp_reader = "${local.name_prefix}-grafana-amp-reader"
    grafana_workspace  = "${local.name_prefix}-grafana-workspace-role"
    chatbot            = "${local.name_prefix}-chatbot-role"
  }

  # Current AWS account and region
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.name
}

# Data sources for current AWS context
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Terraform remote state for Atlantis ECS cluster
data "terraform_remote_state" "atlantis" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "atlantis/terraform.tfstate"
    region = var.aws_region
  }
}
