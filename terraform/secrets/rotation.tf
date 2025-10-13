# Lambda Function for Secrets Rotation

# IAM Role for Lambda execution
resource "aws_iam_role" "rotation_lambda" {
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
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.rotation_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy for Lambda to manage secrets
resource "aws_iam_role_policy" "rotation_lambda_policy" {
  name = "rotation-lambda-policy"
  role = aws_iam_role.rotation_lambda.id

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
resource "aws_cloudwatch_log_group" "rotation_lambda" {
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

# Lambda function for generic secret rotation
resource "aws_lambda_function" "rotation" {
  filename         = "${path.module}/lambda/rotation.zip"
  function_name    = "secrets-manager-rotation"
  role             = aws_iam_role.rotation_lambda.arn
  handler          = "index.lambda_handler"
  source_code_hash = fileexists("${path.module}/lambda/rotation.zip") ? filebase64sha256("${path.module}/lambda/rotation.zip") : null
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${var.aws_region}.amazonaws.com"
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name = "secrets-manager-rotation"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.rotation_lambda
  ]
}

# Permission for Secrets Manager to invoke Lambda
resource "aws_lambda_permission" "allow_secrets_manager" {
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
}

# CloudWatch alarm for rotation failures
resource "aws_cloudwatch_metric_alarm" "rotation_failures" {
  alarm_name          = "secrets-manager-rotation-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when secret rotation fails"

  dimensions = {
    FunctionName = aws_lambda_function.rotation.function_name
  }

  alarm_actions = [] # Add SNS topic ARN for notifications

  tags = merge(
    local.required_tags,
    {
      Name = "rotation-failures-alarm"
    }
  )
}
