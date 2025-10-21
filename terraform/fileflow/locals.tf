# Local Variables

locals {
  # Required tags for all resources
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.lifecycle_stage
    DataClass   = var.data_class
    Service     = "fileflow"
  }

  # Service naming
  service_name = "fileflow"
  cluster_name = var.ecs_cluster_name

  # ECR repository
  ecr_repository_url = "646886795421.dkr.ecr.ap-northeast-2.amazonaws.com/fileflow"

  # Container configuration
  container_name = "fileflow"
  container_port = var.container_port
}
