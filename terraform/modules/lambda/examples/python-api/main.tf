# Python API Lambda Example
#
# This example demonstrates deploying a Python Lambda function
# with API Gateway integration, VPC configuration, and CloudWatch Logs.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources for existing resources
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Type = "private"
  }
}

# Required Tags for Governance
locals {
  required_tags = {
    Environment = var.environment
    Service     = var.service_name
    Team        = "platform-team"
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
    Project     = "lambda-module-example"
  }
}

# KMS Key for CloudWatch Logs encryption
resource "aws_kms_key" "logs" {
  description             = "KMS key for Lambda CloudWatch Logs encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.service_name}-logs-kms-${var.environment}"
      Component = "kms"
      DataClass = "logs"
    }
  )
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.service_name}-logs-${var.environment}"
  target_key_id = aws_kms_key.logs.key_id
}

# KMS Key for DLQ encryption
resource "aws_kms_key" "dlq" {
  description             = "KMS key for Lambda DLQ encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.service_name}-dlq-kms-${var.environment}"
      Component = "kms"
      DataClass = "sqs"
    }
  )
}

resource "aws_kms_alias" "dlq" {
  name          = "alias/${var.service_name}-dlq-${var.environment}"
  target_key_id = aws_kms_key.dlq.key_id
}

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name        = "${var.service_name}-lambda-${var.environment}"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  # Egress to internet (for API calls, external services)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.service_name}-lambda-${var.environment}"
      Component = "security-group"
    }
  )
}

# Lambda Function Module
module "api_lambda" {
  source = "../../"

  # Required tags
  environment = var.environment
  service     = var.service_name
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  project     = "lambda-module-example"

  # Lambda Configuration
  name        = "api"
  description = "Python API Lambda function example"
  handler     = "lambda_function.lambda_handler"
  runtime     = "python3.11"
  timeout     = 30
  memory_size = 256

  # Code deployment (using local file)
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  # Environment variables
  environment_variables = {
    ENVIRONMENT = var.environment
    LOG_LEVEL   = "INFO"
    API_VERSION = "v1"
  }

  # VPC Configuration
  vpc_config = {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  # CloudWatch Logs
  create_log_group   = true
  log_retention_days = 14
  log_kms_key_id     = aws_kms_key.logs.arn

  # Dead Letter Queue
  create_dlq                    = true
  dlq_message_retention_seconds = 1209600 # 14 days
  dlq_kms_key_id                = aws_kms_key.dlq.arn

  # X-Ray Tracing
  tracing_mode = "Active"

  # Versioning
  publish = true

  # Lambda Aliases
  aliases = {
    live = {
      description      = "Live production alias"
      function_version = "$LATEST"
      routing_config   = null
    }
  }

  # Additional custom policies
  custom_policy_arns = var.custom_policy_arns

  # Additional tags
  additional_tags = {
    Component = "api"
    Runtime   = "python3.11"
  }
}

# Example API Gateway REST API (for demonstration purposes)
# NOTE: This is a minimal example to make the Lambda permission functional.
# In production, you would create a complete API Gateway with stages, methods, etc.
resource "aws_api_gateway_rest_api" "example" {
  count = var.enable_api_gateway ? 1 : 0

  name = "${var.service_name}-example-api-${var.environment}"

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.service_name}-example-api-${var.environment}"
      Component = "api-gateway"
    }
  )
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api-gateway" {
  count = var.enable_api_gateway ? 1 : 0

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.api_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # Use the example API Gateway's execution ARN
  source_arn = "${aws_api_gateway_rest_api.example[0].execution_arn}/*/*"
}

# Outputs
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.api_lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.api_lambda.function_arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN for API Gateway integration"
  value       = module.api_lambda.function_invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = module.api_lambda.role_arn
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = module.api_lambda.log_group_name
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = module.api_lambda.dlq_url
}

output "live_alias_arn" {
  description = "ARN of the live alias"
  value       = module.api_lambda.aliases["live"].arn
}
