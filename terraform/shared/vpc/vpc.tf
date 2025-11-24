# ============================================================================
# VPC
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  instance_tenancy     = "default"

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-vpc"
    }
  )

  # Imported existing VPC - preserve existing tags
  lifecycle {
    ignore_changes = [tags]
  }
}

# ============================================================================
# VPC Flow Logs
# ============================================================================

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc-flow-logs" {
  name              = "/aws/vpc/${local.name_prefix}-flow-logs"
  retention_in_days = 7
  kms_key_id        = var.flow_logs_kms_key_id

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-vpc-flow-logs"
    }
  )
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc-flow-logs" {
  name = "${local.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-vpc-flow-logs-role"
    }
  )
}

# IAM Policy for VPC Flow Logs
resource "aws_iam_role_policy" "vpc-flow-logs" {
  name = "${local.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc-flow-logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

# VPC Flow Log
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc-flow-logs.arn
  log_destination = aws_cloudwatch_log_group.vpc-flow-logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-vpc-flow-log"
    }
  )
}

# ============================================================================
# Internet Gateway
# ============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-igw"
    }
  )

  # Imported existing IGW - preserve existing tags
  lifecycle {
    ignore_changes = [tags]
  }
}
