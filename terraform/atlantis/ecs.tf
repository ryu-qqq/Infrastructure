# ECS Cluster for Atlantis

resource "aws_ecs_cluster" "atlantis" {
  name = "atlantis-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-${var.environment}"
      Component   = "atlantis"
      Description = "ECS cluster for Atlantis Terraform automation server"
    }
  )
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "atlantis" {
  cluster_name = aws_ecs_cluster.atlantis.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# Output the cluster information
output "atlantis_ecs_cluster_id" {
  description = "The ID of the Atlantis ECS cluster"
  value       = aws_ecs_cluster.atlantis.id
}

output "atlantis_ecs_cluster_name" {
  description = "The name of the Atlantis ECS cluster"
  value       = aws_ecs_cluster.atlantis.name
}

output "atlantis_ecs_cluster_arn" {
  description = "The ARN of the Atlantis ECS cluster"
  value       = aws_ecs_cluster.atlantis.arn
}
