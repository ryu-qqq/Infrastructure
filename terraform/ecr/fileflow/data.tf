# Get current AWS account
data "aws_caller_identity" "current" {}

# KMS key for ECR encryption (from SSM Parameter)
data "aws_ssm_parameter" "ecs_secrets_key_arn" {
  name = "/shared/kms/ecs-secrets-key-arn"
}
