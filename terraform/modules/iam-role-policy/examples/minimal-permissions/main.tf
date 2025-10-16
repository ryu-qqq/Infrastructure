# Minimal Permissions Example (Least Privilege)
# This demonstrates how to create a role with minimal required permissions

module "minimal_lambda_role" {
  source = "../../"

  role_name   = "example-minimal-lambda-role"
  description = "Lambda role with minimal required permissions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # CloudWatch Logs만 활성화 (로그 작성은 필수)
  enable_cloudwatch_logs_policy = true
  cloudwatch_log_group_arns = [
    "arn:aws:logs:ap-northeast-2:123456789012:log-group:/aws/lambda/example-function"
  ]
  # 로그 그룹은 미리 생성되어 있다고 가정
  cloudwatch_allow_create_log_group = false

  # 필요한 시크릿만 읽기 권한 (쓰기/삭제 없음)
  enable_secrets_manager_policy = true
  secrets_manager_secret_arns = [
    "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:example/lambda/api-key-abc123"
  ]
  secrets_manager_allow_create = false
  secrets_manager_allow_update = false
  secrets_manager_allow_delete = false

  # S3 읽기 전용 (특정 경로만)
  enable_s3_policy = true
  s3_bucket_arns = [
    "arn:aws:s3:::example-config-bucket"
  ]
  s3_object_arns = [
    "arn:aws:s3:::example-config-bucket/lambda/config.json"
  ]
  s3_allow_write = false
  s3_allow_list  = false

  # KMS 복호화만 (특정 키만)
  kms_key_arns = [
    "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  ]

  common_tags = {
    Environment = "production"
    Project     = "example-lambda"
    ManagedBy   = "terraform"
    Security    = "least-privilege"
  }
}

# Example of a read-only data processor role
module "minimal_data_processor_role" {
  source = "../../"

  role_name   = "example-data-processor-role"
  description = "Read-only role for data processing"

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

  # RDS 읽기 전용 (쓰기 권한 없음)
  enable_rds_policy = true
  rds_cluster_arns = [
    "arn:aws:rds:ap-northeast-2:123456789012:cluster:example-readonly-cluster"
  ]

  # S3 읽기 전용
  enable_s3_policy = true
  s3_bucket_arns = [
    "arn:aws:s3:::example-data-lake"
  ]
  s3_object_arns = [
    "arn:aws:s3:::example-data-lake/processed/*"
  ]
  s3_allow_write = false
  s3_allow_list  = true

  # CloudWatch Logs 작성
  enable_cloudwatch_logs_policy = true
  cloudwatch_log_group_arns = [
    "arn:aws:logs:ap-northeast-2:123456789012:log-group:/ecs/data-processor"
  ]

  common_tags = {
    Environment = "production"
    Project     = "data-processor"
    ManagedBy   = "terraform"
    Security    = "read-only"
  }
}

# Outputs
output "lambda_role_arn" {
  description = "ARN of the minimal Lambda role"
  value       = module.minimal_lambda_role.role_arn
}

output "data_processor_role_arn" {
  description = "ARN of the read-only data processor role"
  value       = module.minimal_data_processor_role.role_arn
}
