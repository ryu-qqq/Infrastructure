# ECS Cluster for n8n

resource "aws_ecs_cluster" "n8n" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    local.required_tags,
    {
      Name        = local.name_prefix
      Description = "ECS cluster for n8n workflow automation"
    }
  )
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "n8n" {
  cluster_name = aws_ecs_cluster.n8n.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# Outputs
output "ecs_cluster_id" {
  description = "The ID of the n8n ECS cluster"
  value       = aws_ecs_cluster.n8n.id
}

output "ecs_cluster_name" {
  description = "The name of the n8n ECS cluster"
  value       = aws_ecs_cluster.n8n.name
}

output "ecs_cluster_arn" {
  description = "The ARN of the n8n ECS cluster"
  value       = aws_ecs_cluster.n8n.arn
}
