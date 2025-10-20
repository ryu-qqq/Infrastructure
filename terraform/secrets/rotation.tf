# Lambda Function for Secrets Rotation

# IAM Role for Lambda execution
resource "aws_iam_role" "rotation-lambda" {
  name = "secrets-manager-rotation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name = "secrets-manager-rotation-lambda-role"
    }
  )
}

# Attach AWS managed policy for Lambda VPC execution (if needed)
resource "aws_iam_role_policy_attachment" "lambda-vpc-execution" {
  role       = aws_iam_role.rotation-lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy for Lambda to manage secrets
resource "aws_iam_role_policy" "rotation-lambda-policy" {
  name = "rotation-lambda-policy"
  role = aws_iam_role.rotation-lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:/${local.org_name}/*"
      },
      {
        Sid    = "AllowKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = data.terraform_remote_state.kms.outputs.secrets_manager_key_arn
      },
      {
        Sid    = "AllowGetRandomPassword"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetRandomPassword"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowRDSAccess"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "rotation-lambda" {
  name              = "/aws/lambda/secrets-manager-rotation"
  retention_in_days = 14
  kms_key_id        = data.terraform_remote_state.kms.outputs.secrets_manager_key_arn

  tags = merge(
    local.required_tags,
    {
      Name = "secrets-manager-rotation-logs"
    }
  )
}

# Security Group for Lambda rotation function
resource "aws_security_group" "rotation-lambda" {
  count       = var.vpc_id != "" ? 1 : 0
  name        = "secrets-manager-rotation-lambda-sg"
  description = "Security group for Secrets Manager rotation Lambda"
  vpc_id      = var.vpc_id

  # Outbound rules
  egress {
    description = "Allow HTTPS to Secrets Manager"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow MySQL to RDS within VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.vpc_cidr != "" ? [var.vpc_cidr] : ["0.0.0.0/0"]
  }

  tags = merge(
    local.required_tags,
    {
      Name = "secrets-manager-rotation-lambda-sg"
    }
  )
}

# Lambda function for generic secret rotation
resource "aws_lambda_function" "rotation" {
  filename         = "${path.module}/lambda/rotation.zip"
  function_name    = "secrets-manager-rotation"
  role             = aws_iam_role.rotation-lambda.arn
  handler          = "index.lambda_handler"
  source_code_hash = fileexists("${path.module}/lambda/rotation.zip") ? filebase64sha256("${path.module}/lambda/rotation.zip") : null
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${var.aws_region}.amazonaws.com"
    }
  }

  # VPC configuration for RDS access
  dynamic "vpc_config" {
    for_each = var.vpc_id != "" ? [1] : []
    content {
      subnet_ids         = var.private_subnet_ids
      security_group_ids = [aws_security_group.rotation-lambda[0].id]
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name = "secrets-manager-rotation"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.rotation-lambda
  ]
}

# Permission for Secrets Manager to invoke Lambda
resource "aws_lambda_permission" "allow-secrets-manager" {
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
}

# CloudWatch alarm for rotation failures
resource "aws_cloudwatch_metric_alarm" "rotation-failures" {
  alarm_name          = "secrets-manager-rotation-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when Secrets Manager rotation Lambda fails. This requires immediate attention as password rotation failure could impact security compliance."
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.rotation.function_name
  }

  alarm_actions = [] # TODO: Add SNS topic ARN for notifications when monitoring stack is available

  tags = merge(
    local.required_tags,
    {
      Name      = "rotation-failures-alarm"
      Severity  = "high"
      Runbook   = "https://github.com/ryu-qqq/Infrastructure/wiki/Secrets-Rotation-Runbook"
      Component = "security"
    }
  )
}

# CloudWatch alarm for rotation duration
resource "aws_cloudwatch_metric_alarm" "rotation-duration" {
  alarm_name          = "secrets-manager-rotation-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Maximum"
  threshold           = 50000 # 50 seconds (Lambda timeout is 60s)
  alarm_description   = "Alert when rotation Lambda takes longer than expected. May indicate database performance issues."
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.rotation.function_name
  }

  alarm_actions = [] # TODO: Add SNS topic ARN for notifications

  tags = merge(
    local.required_tags,
    {
      Name      = "rotation-duration-alarm"
      Severity  = "medium"
      Component = "performance"
    }
  )
}
