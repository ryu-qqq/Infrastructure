# ============================================================================
# Bastion Host IAM Role for SSM Session Manager
# ============================================================================

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# IAM Role for Bastion Host
resource "aws_iam_role" "bastion" {
  name               = "${var.environment}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role.json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-bastion-role"
    }
  )
}

# Assume Role Policy Document
data "aws_iam_policy_document" "bastion_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Attach AWS Managed Policy for SSM
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Additional CloudWatch Logs Policy for Session Logging
resource "aws_iam_role_policy" "bastion_cloudwatch_logs" {
  count = var.enable_session_logging ? 1 : 0

  name = "${var.environment}-bastion-cloudwatch-logs"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ssm/bastion/*"
        ]
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "bastion" {
  name = "${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-bastion-profile"
    }
  )
}
