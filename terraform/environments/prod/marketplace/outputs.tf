# Outputs for Marketplace IAM Module

output "iam_user_name" {
  description = "The name of the IAM user"
  value       = aws_iam_user.marketplace.name
}

output "iam_user_arn" {
  description = "The ARN of the IAM user"
  value       = aws_iam_user.marketplace.arn
}

output "access_key_id" {
  description = "The access key ID"
  value       = aws_iam_access_key.marketplace.id
  sensitive   = true
}

output "secret_access_key" {
  description = "The secret access key"
  value       = aws_iam_access_key.marketplace.secret
  sensitive   = true
}

# Policy ARNs for reference
output "textract_policy_arn" {
  description = "The ARN of the Textract policy"
  value       = aws_iam_policy.marketplace_textract.arn
}

output "ses_policy_arn" {
  description = "The ARN of the SES policy"
  value       = aws_iam_policy.marketplace_ses.arn
}

output "s3_policy_arn" {
  description = "The ARN of the S3 policy"
  value       = aws_iam_policy.marketplace_s3.arn
}
