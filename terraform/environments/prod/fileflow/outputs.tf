output "role_policy_arn" {
  description = "ARN of the IAM Role Policy"
  value       = aws_iam_role_policy.atlantis_ecs_task_policy.id
}