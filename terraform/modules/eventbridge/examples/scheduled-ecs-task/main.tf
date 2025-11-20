# ========================================
# Example: Scheduled ECS Task
# ========================================
# This example shows how to run an ECS task
# on a schedule using EventBridge
# ========================================

module "crawler_scheduler" {
  source = "../../"

  name        = "crawler-scheduler"
  description = "Run crawler task every hour"
  target_type = "ecs"

  # 매시간 실행
  schedule_expression = "rate(1 hour)"

  # ECS 설정
  ecs_cluster_arn         = "arn:aws:ecs:ap-northeast-2:123456789012:cluster/main"
  ecs_task_definition_arn = "arn:aws:ecs:ap-northeast-2:123456789012:task-definition/crawler:1"
  ecs_task_count          = 1
  ecs_launch_type         = "FARGATE"

  ecs_network_configuration = {
    subnets          = ["subnet-12345678", "subnet-87654321"]
    security_groups  = ["sg-12345678"]
    assign_public_ip = false
  }

  ecs_task_role_arns = [
    "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
    "arn:aws:iam::123456789012:role/ecsTaskRole"
  ]

  common_tags = {
    Environment = "prod"
    Service     = "crawler"
    Team        = "data-team"
    Owner       = "data@example.com"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
    Project     = "crawlinghub"
  }
}

output "rule_arn" {
  value = module.crawler_scheduler.rule_arn
}

output "eventbridge_role_arn" {
  value = module.crawler_scheduler.eventbridge_role_arn
}
