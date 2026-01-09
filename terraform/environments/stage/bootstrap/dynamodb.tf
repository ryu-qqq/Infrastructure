# DynamoDB table for Stage Terraform state locking
resource "aws_dynamodb_table" "terraform-lock" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.terraform-state.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.required_tags, {
    Name      = var.dynamodb_table_name
    Component = "dynamodb"
  })
}
