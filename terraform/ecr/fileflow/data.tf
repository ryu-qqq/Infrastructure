# Data Sources for ECR FileFlow

# Current AWS Account
data "aws_caller_identity" "current" {}

# KMS Key for ECS Secrets (from SSM Parameter Store)
data "aws_ssm_parameter" "ecs-secrets-key-arn" {
  name = "/shared/kms/ecs-secrets-key-arn"
}
