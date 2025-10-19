# Lambda Function Module Outputs

# Lambda Function
output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "function_qualified_arn" {
  description = "Qualified ARN of the Lambda function"
  value       = aws_lambda_function.this.qualified_arn
}

output "function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.this.invoke_arn
}

output "function_version" {
  description = "Latest published version of the Lambda function"
  value       = aws_lambda_function.this.version
}

output "function_last_modified" {
  description = "Date the Lambda function was last modified"
  value       = aws_lambda_function.this.last_modified
}

output "function_source_code_hash" {
  description = "Base64-encoded SHA256 hash of the package file"
  value       = aws_lambda_function.this.source_code_hash
}

output "function_source_code_size" {
  description = "Size in bytes of the function .zip file"
  value       = aws_lambda_function.this.source_code_size
}

# IAM Role
output "role_arn" {
  description = "ARN of the IAM role"
  value       = var.create_role ? aws_iam_role.lambda[0].arn : var.lambda_role_arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = var.create_role ? aws_iam_role.lambda[0].name : null
}

output "role_id" {
  description = "ID of the IAM role"
  value       = var.create_role ? aws_iam_role.lambda[0].id : null
}

# CloudWatch Log Group
output "log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = var.create_log_group ? aws_cloudwatch_log_group.lambda[0].name : null
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  value       = var.create_log_group ? aws_cloudwatch_log_group.lambda[0].arn : null
}

# Dead Letter Queue
output "dlq_arn" {
  description = "ARN of the Dead Letter Queue"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].url : null
}

# Lambda Aliases
output "aliases" {
  description = "Map of Lambda function aliases"
  value = {
    for alias_name, alias in aws_lambda_alias.this : alias_name => {
      arn              = alias.arn
      invoke_arn       = alias.invoke_arn
      function_version = alias.function_version
    }
  }
}

# Lambda Permissions
output "permissions" {
  description = "Map of Lambda permissions"
  value = {
    for permission_name, permission in aws_lambda_permission.this : permission_name => {
      statement_id = permission.statement_id
    }
  }
}
