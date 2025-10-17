# ECS Task Role Example
# This role is used by the ECS task at runtime to access AWS services

module "ecs_task_role" {
  source = "../../"

  role_name   = "example-ecs-task-role"
  description = "ECS task role with RDS, Secrets Manager, and S3 access"

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

  # ECS Task 기본 권한
  enable_ecs_task_policy = true

  # RDS 접근 권한
  enable_rds_policy = true
  rds_cluster_arns = [
    "arn:aws:rds:ap-northeast-2:123456789012:cluster:example-db-cluster"
  ]

  # Secrets Manager 접근 권한 (읽기 전용)
  enable_secrets_manager_policy = true
  secrets_manager_secret_arns = [
    "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:example/db/password-abc123",
    "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:example/api/key-def456"
  ]
  secrets_manager_allow_create = false
  secrets_manager_allow_update = false
  secrets_manager_allow_delete = false

  # S3 접근 권한 (읽기/쓰기)
  enable_s3_policy = true
  s3_bucket_arns = [
    "arn:aws:s3:::example-app-data"
  ]
  s3_object_arns = [
    "arn:aws:s3:::example-app-data/uploads/*"
  ]
  s3_allow_write = true
  s3_allow_list  = true

  # CloudWatch Logs 권한
  enable_cloudwatch_logs_policy = true
  cloudwatch_log_group_arns = [
    "arn:aws:logs:ap-northeast-2:123456789012:log-group:/aws/ecs/production/example-app"
  ]

  # KMS 암호화 키
  kms_key_arns = [
    "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  ]

  common_tags = {
    Environment = "production"
    Project     = "example-app"
    ManagedBy   = "terraform"
  }
}

# Output the role ARN for use in ECS task definition
output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.ecs_task_role.role_arn
}

output "task_role_name" {
  description = "Name of the ECS task role"
  value       = module.ecs_task_role.role_name
}
