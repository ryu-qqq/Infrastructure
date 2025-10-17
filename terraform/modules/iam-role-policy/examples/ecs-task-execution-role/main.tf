# ECS Task Execution Role Example
# This role is used by ECS to start containers (pulling images, logging, etc.)

module "ecs_task_execution_role" {
  source = "../../"

  role_name   = "example-ecs-task-execution-role"
  description = "ECS task execution role for pulling images and writing logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # ECS Task Execution 권한 활성화
  enable_ecs_task_execution_policy = true

  # ECR 리포지토리 ARN
  ecr_repository_arns = [
    "arn:aws:ecr:ap-northeast-2:123456789012:repository/example-app",
    "arn:aws:ecr:ap-northeast-2:123456789012:repository/example-app-sidecar"
  ]

  # CloudWatch Logs 그룹
  cloudwatch_log_group_arns = [
    "arn:aws:logs:ap-northeast-2:123456789012:log-group:/aws/ecs/production/example-app"
  ]

  # KMS 키 (ECR 이미지 및 로그 암호화)
  kms_key_arns = [
    "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  ]

  # Secrets Manager 접근 (환경 변수 주입용)
  enable_secrets_manager_policy = true
  secrets_manager_secret_arns = [
    "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:example/app/config-abc123"
  ]
  secrets_manager_allow_create = false
  secrets_manager_allow_update = false
  secrets_manager_allow_delete = false

  common_tags = {
    Environment = "production"
    Project     = "example-app"
    ManagedBy   = "terraform"
  }
}

# Output the role ARN for use in ECS task definition
output "execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.ecs_task_execution_role.role_arn
}

output "execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = module.ecs_task_execution_role.role_name
}
