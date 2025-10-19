# ALB 출력
output "alb_dns_name" {
  description = "Application Load Balancer의 DNS 이름"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Application Load Balancer의 Hosted Zone ID (Route53 연동용)"
  value       = aws_lb.main.zone_id
}

# Target Group 출력
output "target_group_arn" {
  description = "Target Group ARN"
  value       = aws_lb_target_group.app.arn
}

# ECS Service 출력
output "ecs_cluster_id" {
  description = "ECS 클러스터 ID"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "ECS 클러스터 이름"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_id" {
  description = "ECS 서비스 ID"
  value       = module.ecs_service.service_id
}

output "ecs_service_name" {
  description = "ECS 서비스 이름"
  value       = module.ecs_service.service_name
}

output "task_definition_arn" {
  description = "Task Definition ARN"
  value       = module.ecs_service.task_definition_arn
}

# CloudWatch Logs 출력
output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group 이름"
  value       = module.ecs_service.cloudwatch_log_group_name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch Log Group ARN"
  value       = module.ecs_service.cloudwatch_log_group_arn
}

# 보안 그룹 출력
output "alb_security_group_id" {
  description = "ALB 보안 그룹 ID"
  value       = aws_security_group.alb.id
}

output "ecs_tasks_security_group_id" {
  description = "ECS Tasks 보안 그룹 ID"
  value       = aws_security_group.ecs-tasks.id
}

# 접속 정보
output "application_url" {
  description = "애플리케이션 접속 URL"
  value       = "http://${aws_lb.main.dns_name}"
}
