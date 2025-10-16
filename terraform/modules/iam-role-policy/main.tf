# IAM Role with configurable policies for ECS, RDS, Secrets Manager, S3, and CloudWatch Logs

# ============================================================================
# IAM Role
# ============================================================================

resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = var.description != "" ? var.description : "IAM role for ${var.role_name}"
  assume_role_policy   = var.assume_role_policy
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary

  tags = merge(
    var.common_tags,
    {
      Name        = var.role_name
      Description = var.description != "" ? var.description : "IAM role for ${var.role_name}"
    }
  )
}

# ============================================================================
# AWS Managed Policy Attachments
# ============================================================================

resource "aws_iam_role_policy_attachment" "aws_managed" {
  for_each = toset(var.attach_aws_managed_policies)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# ============================================================================
# ECS Task Execution Policy
# ============================================================================

# Standard ECS task execution policy for pulling images and publishing logs
resource "aws_iam_role_policy" "ecs_task_execution" {
  count = var.enable_ecs_task_execution_policy ? 1 : 0

  name = "${var.role_name}-ecs-task-execution"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # ECR image pull permissions - repository specific
      length(var.ecr_repository_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = var.ecr_repository_arns
      }] : [],
      # ECR GetAuthorizationToken - requires wildcard
      length(var.ecr_repository_arns) > 0 ? [{
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      }] : [],
      # KMS decryption for ECR images
      length(var.kms_key_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arns
      }] : [],
      # CloudWatch Logs for container logs
      length(var.cloudwatch_log_group_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = var.cloudwatch_log_group_arns
      }] : []
    )
  })
}

# ============================================================================
# ECS Task Policy
# ============================================================================

# Basic ECS task role policy for container runtime
resource "aws_iam_role_policy" "ecs_task" {
  count = var.enable_ecs_task_policy ? 1 : 0

  name = "${var.role_name}-ecs-task"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# RDS Access Policy
# ============================================================================

resource "aws_iam_role_policy" "rds" {
  count = var.enable_rds_policy ? 1 : 0

  name = "${var.role_name}-rds-access"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # RDS cluster permissions
      length(var.rds_cluster_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "rds:DescribeDBClusters",
          "rds:DescribeDBClusterEndpoints"
        ]
        Resource = var.rds_cluster_arns
      }] : [],
      # RDS instance permissions
      length(var.rds_db_instance_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances"
        ]
        Resource = var.rds_db_instance_arns
      }] : [],
      # RDS IAM authentication (if using IAM database authentication)
      (length(var.rds_cluster_arns) > 0 || length(var.rds_db_instance_arns) > 0) ? [{
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = concat(
          [for arn in var.rds_cluster_arns : "${arn}/*"],
          [for arn in var.rds_db_instance_arns : "${arn}/*"]
        )
      }] : []
    )
  })
}

# ============================================================================
# Secrets Manager Access Policy
# ============================================================================

resource "aws_iam_role_policy" "secrets_manager" {
  count = var.enable_secrets_manager_policy ? 1 : 0

  name = "${var.role_name}-secrets-manager"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Read access to secrets
      length(var.secrets_manager_secret_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.secrets_manager_secret_arns
      }] : [],
      # Create secret permissions
      var.secrets_manager_allow_create ? [{
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:TagResource"
        ]
        Resource = "*"
      }] : [],
      # Update secret permissions
      var.secrets_manager_allow_update && length(var.secrets_manager_secret_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = var.secrets_manager_secret_arns
      }] : [],
      # Delete secret permissions
      var.secrets_manager_allow_delete && length(var.secrets_manager_secret_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "secretsmanager:DeleteSecret"
        ]
        Resource = var.secrets_manager_secret_arns
      }] : [],
      # KMS decryption for encrypted secrets
      length(var.kms_key_arns) > 0 && length(var.secrets_manager_secret_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arns
      }] : []
    )
  })
}

# ============================================================================
# S3 Access Policy
# ============================================================================

resource "aws_iam_role_policy" "s3" {
  count = var.enable_s3_policy ? 1 : 0

  name = "${var.role_name}-s3-access"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Bucket-level permissions
      var.s3_allow_list && length(var.s3_bucket_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = var.s3_bucket_arns
      }] : [],
      # Object read permissions
      length(var.s3_object_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = var.s3_object_arns
      }] : [],
      # Object write permissions
      var.s3_allow_write && length(var.s3_object_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = var.s3_object_arns
      }] : [],
      # KMS encryption/decryption for S3 objects
      length(var.kms_key_arns) > 0 && length(var.s3_object_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arns
      }] : []
    )
  })
}

# ============================================================================
# CloudWatch Logs Access Policy
# ============================================================================

resource "aws_iam_role_policy" "cloudwatch_logs" {
  count = var.enable_cloudwatch_logs_policy ? 1 : 0

  name = "${var.role_name}-cloudwatch-logs"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Create log group permission
      var.cloudwatch_allow_create_log_group ? [{
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:*"
      }] : [],
      # Write to log streams
      length(var.cloudwatch_log_group_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          for arn in var.cloudwatch_log_group_arns : "${arn}:*"
        ]
      }] : [],
      # KMS encryption for CloudWatch Logs
      length(var.kms_key_arns) > 0 && length(var.cloudwatch_log_group_arns) > 0 ? [{
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arns
      }] : []
    )
  })
}

# ============================================================================
# Custom Inline Policies
# ============================================================================

resource "aws_iam_role_policy" "custom" {
  for_each = var.custom_inline_policies

  name   = "${var.role_name}-${each.key}"
  role   = aws_iam_role.this.id
  policy = each.value.policy
}
