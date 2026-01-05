output "atlantis_ecs_task_policy_arn" {
  description = "The ARN of the Atlantis ECS Task Role IAM policy"
  value       = aws_iam_policy.atlantis_ecs_task_policy.arn
}