# Lambda Function for Secrets Rotation

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
      Name      = "secrets-manager-rotation-lambda-sg"
      Component = "security-group"
    }
  )
}

# IAM Role for Lambda using iam-role-policy module
module "rotation_lambda_role" {
  source = "../../../modules/iam-role-policy"

  role_name   = "secrets-manager-rotation-lambda-role"
  description = "IAM role for Secrets Manager rotation Lambda function"

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

  # Required tags
  environment  = var.environment
  service_name = var.service
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = var.data_class

  # Attach AWS managed policies
  attach_aws_managed_policies = var.vpc_id != "" ? [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ] : []

  # Enable Secrets Manager policy
  enable_secrets_manager_policy = true
  secrets_manager_allow_update  = true
  secrets_manager_secret_arns   = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:/${local.org_name}/*"]

  # KMS key access
  kms_key_arns = [local.secrets_manager_kms_key_arn]

  # Enable CloudWatch Logs policy
  enable_cloudwatch_logs_policy = true
  cloudwatch_log_group_arns     = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:${local.lambda_log_group}"]

  # Custom inline policy for RDS and GetRandomPassword
  custom_inline_policies = {
    rds-access = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
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
  }

  additional_tags = {
    Component = "lambda-role"
  }
}

# Lambda function using lambda module
module "rotation_lambda" {
  source = "../../../modules/lambda"

  # Function configuration
  name        = "rotation"
  handler     = "index.lambda_handler"
  runtime     = "python3.11"
  timeout     = 60
  memory_size = 128

  # Code deployment
  filename         = "${path.module}/lambda/rotation.zip"
  source_code_hash = fileexists("${path.module}/lambda/rotation.zip") ? filebase64sha256("${path.module}/lambda/rotation.zip") : null

  # Environment variables
  environment_variables = {
    SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${var.aws_region}.amazonaws.com"
  }

  # VPC configuration for RDS access
  vpc_config = var.vpc_id != "" ? {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.rotation-lambda[0].id]
  } : null

  # Use existing IAM role from module
  create_role     = false
  lambda_role_arn = module.rotation_lambda_role.role_arn

  # CloudWatch Logs
  create_log_group   = true
  log_retention_days = 14
  log_kms_key_id     = local.cloudwatch_logs_kms_key_arn

  # Required tags
  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project
  data_class  = var.data_class

  additional_tags = {
    Component = "rotation-lambda"
  }
}

# Permission for Secrets Manager to invoke Lambda
resource "aws_lambda_permission" "allow-secrets-manager" {
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = module.rotation_lambda.function_name
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
    FunctionName = module.rotation_lambda.function_name
  }

  alarm_actions = [] # TODO: Add SNS topic ARN for notifications when monitoring stack is available

  tags = merge(
    local.required_tags,
    {
      Name      = "rotation-failures-alarm"
      Severity  = "high"
      Runbook   = "https://github.com/ryu-qqq/Infrastructure/wiki/Secrets-Rotation-Runbook"
      Component = "monitoring"
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
    FunctionName = module.rotation_lambda.function_name
  }

  alarm_actions = [] # TODO: Add SNS topic ARN for notifications

  tags = merge(
    local.required_tags,
    {
      Name      = "rotation-duration-alarm"
      Severity  = "medium"
      Component = "monitoring"
    }
  )
}
