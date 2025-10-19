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
output "api_target_group_arn" {
  description = "API Target Group ARN"
  value       = aws_lb_target_group.api.arn
}

output "web_target_group_arn" {
  description = "Web Target Group ARN"
  value       = aws_lb_target_group.web.arn
}

output "admin_target_group_arn" {
  description = "Admin Target Group ARN"
  value       = aws_lb_target_group.admin.arn
}

# 보안 그룹 출력
output "alb_security_group_id" {
  description = "ALB 보안 그룹 ID"
  value       = aws_security_group.alb.id
}

# 라우팅 정보
output "routing_info" {
  description = "라우팅 경로 정보"
  value = {
    api_path    = "/api/*"
    admin_path  = "/admin/*"
    web_path    = "/ (default)"
    health_path = "/health, /healthz"
  }
}

# 접속 URL
output "service_urls" {
  description = "서비스별 접속 URL"
  value = {
    api    = "https://${aws_lb.main.dns_name}/api"
    admin  = "https://${aws_lb.main.dns_name}/admin"
    web    = "https://${aws_lb.main.dns_name}"
    health = "https://${aws_lb.main.dns_name}/health"
  }
}
