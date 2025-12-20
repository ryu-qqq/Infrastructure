# DynamoDB Module Outputs

output "table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.this.arn
}

output "table_id" {
  description = "ID of the DynamoDB table"
  value       = aws_dynamodb_table.this.id
}

output "hash_key" {
  description = "Hash key of the table"
  value       = aws_dynamodb_table.this.hash_key
}

output "range_key" {
  description = "Range key of the table"
  value       = aws_dynamodb_table.this.range_key
}

output "stream_arn" {
  description = "ARN of the DynamoDB Stream (if enabled)"
  value       = aws_dynamodb_table.this.stream_arn
}

output "stream_label" {
  description = "Timestamp of the stream (if enabled)"
  value       = aws_dynamodb_table.this.stream_label
}

output "billing_mode" {
  description = "Billing mode of the table"
  value       = aws_dynamodb_table.this.billing_mode
}

output "tags" {
  description = "Tags applied to the table"
  value       = aws_dynamodb_table.this.tags_all
}
