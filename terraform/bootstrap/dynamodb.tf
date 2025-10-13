# DynamoDB Table for Terraform State Locking
#
# This table provides state locking and consistency checking for Terraform.
# Features:
# - On-demand billing for cost optimization
# - Point-in-time recovery for disaster recovery
# - Server-side encryption with KMS (optional, DynamoDB default encryption is sufficient)
# - LockID as partition key (required by Terraform)

resource "aws_dynamodb_table" "terraform-lock" {
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST" # On-demand pricing
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Enable point-in-time recovery for disaster recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side encryption (uses AWS managed key by default)
  # For customer-managed KMS key, uncomment below:
  # server_side_encryption {
  #   enabled     = true
  #   kms_key_arn = aws_kms_key.terraform-state.arn
  # }

  tags = merge(
    local.required_tags,
    {
      Name        = local.lock_table_name
      Component   = "terraform-backend"
      Description = "Terraform state locking for all environments"
    }
  )
}

output "lock_table_name" {
  description = "The name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform-lock.name
}

output "lock_table_arn" {
  description = "The ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform-lock.arn
}
