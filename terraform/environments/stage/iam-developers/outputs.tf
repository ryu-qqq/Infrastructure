# Outputs for Developer IAM User
# IMPORTANT: Access key secret is sensitive - handle with care!

output "developer_user_name" {
  description = "IAM user name"
  value       = aws_iam_user.developer.name
}

output "developer_user_arn" {
  description = "IAM user ARN"
  value       = aws_iam_user.developer.arn
}

output "developer_access_key_id" {
  description = "Access key ID for CLI configuration"
  value       = aws_iam_access_key.developer.id
}

output "developer_secret_access_key" {
  description = "Secret access key for CLI configuration (SENSITIVE - share securely!)"
  value       = aws_iam_access_key.developer.secret
  sensitive   = true
}

output "policy_arn" {
  description = "ARN of the attached policy"
  value       = aws_iam_policy.stage_rds_access.arn
}

# CLI Configuration Instructions
output "cli_configuration_instructions" {
  description = "Instructions for developer to configure AWS CLI"
  value       = <<-EOT

    ========================================
    AWS CLI 설정 방법
    ========================================

    1. 터미널에서 다음 명령어 실행:
       aws configure --profile stage-developer

    2. 다음 값들을 입력:
       - AWS Access Key ID: (terraform output으로 확인)
       - AWS Secret Access Key: (terraform output -raw developer_secret_access_key)
       - Default region name: ap-northeast-2
       - Default output format: json

    3. 포트 포워딩 스크립트 실행:
       AWS_PROFILE=stage-developer ./aws-port-forward-stage.sh

    ========================================
  EOT
}
