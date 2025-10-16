# --- ALB Outputs ---

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer (for CloudWatch metrics)"
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.this.id
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer (for Route53 alias records)"
  value       = aws_lb.this.zone_id
}

# --- Target Group Outputs ---

output "target_group_arns" {
  description = "Map of target group names to their ARNs"
  value = {
    for k, tg in aws_lb_target_group.this : k => tg.arn
  }
}

output "target_group_arn_suffixes" {
  description = "Map of target group names to their ARN suffixes (for CloudWatch metrics)"
  value = {
    for k, tg in aws_lb_target_group.this : k => tg.arn_suffix
  }
}

output "target_group_ids" {
  description = "Map of target group names to their IDs"
  value = {
    for k, tg in aws_lb_target_group.this : k => tg.id
  }
}

output "target_group_names" {
  description = "Map of target group keys to their names"
  value = {
    for k, tg in aws_lb_target_group.this : k => tg.name
  }
}

# --- Listener Outputs ---

output "http_listener_arns" {
  description = "Map of HTTP listener names to their ARNs"
  value = {
    for k, listener in aws_lb_listener.http : k => listener.arn
  }
}

output "http_listener_ids" {
  description = "Map of HTTP listener names to their IDs"
  value = {
    for k, listener in aws_lb_listener.http : k => listener.id
  }
}

output "https_listener_arns" {
  description = "Map of HTTPS listener names to their ARNs"
  value = {
    for k, listener in aws_lb_listener.https : k => listener.arn
  }
}

output "https_listener_ids" {
  description = "Map of HTTPS listener names to their IDs"
  value = {
    for k, listener in aws_lb_listener.https : k => listener.id
  }
}

# --- Listener Rule Outputs ---

output "listener_rule_arns" {
  description = "Map of listener rule names to their ARNs"
  value = {
    for k, rule in aws_lb_listener_rule.this : k => rule.arn
  }
}

output "listener_rule_ids" {
  description = "Map of listener rule names to their IDs"
  value = {
    for k, rule in aws_lb_listener_rule.this : k => rule.id
  }
}
