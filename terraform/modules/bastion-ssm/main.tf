# ============================================================================
# Bastion Host EC2 Instance with SSM Session Manager
# ============================================================================

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Bastion Host Instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  # No key pair needed for SSM Session Manager
  # key_name = null

  # Enable detailed monitoring
  monitoring = var.enable_detailed_monitoring

  # Root volume configuration
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      var.common_tags,
      {
        Name = "${var.environment}-bastion-root-volume"
      }
    )
  }

  # User data for initial setup
  user_data = base64encode(templatefile("${path.module}/files/userdata.sh", {
    environment = var.environment
    region      = var.aws_region
  }))

  # Metadata options for enhanced security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 required
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-bastion"
      Role = "bastion"
    }
  )

  lifecycle {
    ignore_changes = [
      ami, # Prevent replacement on AMI updates
    ]
  }
}

# CloudWatch Log Group for SSM Session Logs
resource "aws_cloudwatch_log_group" "bastion_sessions" {
  count = var.enable_session_logging ? 1 : 0

  name              = "/aws/ssm/bastion/${var.environment}"
  retention_in_days = var.session_log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-bastion-session-logs"
    }
  )
}

# SSM Document for Session Manager Preferences
resource "aws_ssm_document" "bastion_session_preferences" {
  count = var.enable_session_logging ? 1 : 0

  name            = "${var.environment}-bastion-session-preferences"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Document to configure session preferences for bastion host"
    sessionType   = "Standard_Stream"
    inputs = {
      s3BucketName                = ""
      s3KeyPrefix                 = ""
      s3EncryptionEnabled         = true
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.bastion_sessions[0].name
      cloudWatchEncryptionEnabled = true
      cloudWatchStreamingEnabled  = true
      idleSessionTimeout          = "20"
      maxSessionDuration          = "60"
      runAsEnabled                = false
      runAsDefaultUser            = ""
    }
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-bastion-session-preferences"
    }
  )
}
