# ============================================================================
# Enhanced Monitoring IAM Role
# ============================================================================

resource "aws_iam_role" "monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name        = "prod-shared-mysql-monitoring-role"  # 기존 리소스 이름 유지
  description = "IAM role for RDS Enhanced Monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  ]

  tags = merge(
    local.required_tags,
    {
      Name      = "prod-shared-mysql-monitoring-role"
      Component = "database"
    }
  )

  # Import된 리소스 - 기존 태그, 이름, description 보존
  lifecycle {
    ignore_changes = [
      tags,
      name,
      description
    ]
  }
}
