# ============================================================================
# Database Configuration
# ============================================================================

# Random password for fileflow database user
resource "random_password" "fileflow_db_password" {
  length  = 32
  special = true
}

# Store fileflow database credentials in Secrets Manager
resource "aws_secretsmanager_secret" "fileflow_db_credentials" {
  name_prefix             = "${local.name_prefix}-db-credentials-"
  description             = "Database credentials for fileflow service"
  kms_key_id              = data.terraform_remote_state.kms.outputs.secrets_manager_key_arn
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-db-credentials"
      Component = "database"
    }
  )
}

resource "aws_secretsmanager_secret_version" "fileflow_db_credentials" {
  secret_id = aws_secretsmanager_secret.fileflow_db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.fileflow_db_password.result
    database = var.db_name
    host     = data.terraform_remote_state.rds.outputs.endpoint
    port     = 3306
  })
}

# MySQL database and user creation using null_resource
# This will be executed after RDS instance is ready
resource "null_resource" "create_database_and_user" {
  # Trigger on database name or username changes
  triggers = {
    db_name     = var.db_name
    db_username = var.db_username
    rds_endpoint = data.terraform_remote_state.rds.outputs.endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for RDS to be available
      sleep 30

      # Get master credentials from Secrets Manager
      MASTER_CREDS=$(aws secretsmanager get-secret-value \
        --secret-id ${data.terraform_remote_state.rds.outputs.master_user_secret_arn} \
        --query SecretString \
        --output text \
        --region ${var.aws_region})

      MASTER_USER=$(echo $MASTER_CREDS | jq -r .username)
      MASTER_PASS=$(echo $MASTER_CREDS | jq -r .password)
      RDS_HOST="${data.terraform_remote_state.rds.outputs.endpoint}"

      # Create database and user
      mysql -h "$RDS_HOST" -u "$MASTER_USER" -p"$MASTER_PASS" << 'SQL'
        -- Create database if not exists
        CREATE DATABASE IF NOT EXISTS ${var.db_name}
          CHARACTER SET utf8mb4
          COLLATE utf8mb4_unicode_ci;

        -- Create user if not exists
        CREATE USER IF NOT EXISTS '${var.db_username}'@'%'
          IDENTIFIED BY '${random_password.fileflow_db_password.result}';

        -- Grant privileges
        GRANT ALL PRIVILEGES ON ${var.db_name}.* TO '${var.db_username}'@'%';

        -- Flush privileges
        FLUSH PRIVILEGES;
      SQL

      echo "Database ${var.db_name} and user ${var.db_username} created successfully"
    EOT
  }

  depends_on = [
    random_password.fileflow_db_password,
    aws_secretsmanager_secret_version.fileflow_db_credentials
  ]
}

# IAM policy for accessing fileflow-specific database credentials
resource "aws_iam_policy" "fileflow_db_access" {
  name        = "${local.name_prefix}-db-access"
  description = "Policy for fileflow to access its database credentials"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.fileflow_db_credentials.arn,
          "${aws_secretsmanager_secret.fileflow_db_credentials.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = data.terraform_remote_state.kms.outputs.secrets_manager_key_arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-db-access"
      Component = "iam"
    }
  )
}

# Attach database access policy to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_task_fileflow_db" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.fileflow_db_access.arn
}

# CloudWatch Log Group for database query logs (optional, for monitoring)
resource "aws_cloudwatch_log_group" "database_queries" {
  name              = "/aws/rds/${local.service_name}/queries"
  retention_in_days = 7
  kms_key_id        = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-db-queries"
      Component = "logging"
    }
  )
}

# Output database connection information for reference
# This will be used by the application through environment variables and secrets
