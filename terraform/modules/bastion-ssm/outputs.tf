# ============================================================================
# Bastion SSM Module - Outputs
# ============================================================================

output "instance_id" {
  description = "ID of the bastion EC2 instance"
  value       = aws_instance.bastion.id
}

output "instance_arn" {
  description = "ARN of the bastion EC2 instance"
  value       = aws_instance.bastion.arn
}

output "private_ip" {
  description = "Private IP address of the bastion instance"
  value       = aws_instance.bastion.private_ip
}

output "security_group_id" {
  description = "ID of the bastion security group"
  value       = aws_security_group.bastion.id
}

output "iam_role_arn" {
  description = "ARN of the bastion IAM role"
  value       = aws_iam_role.bastion.arn
}

output "iam_role_name" {
  description = "Name of the bastion IAM role"
  value       = aws_iam_role.bastion.name
}

output "vpc_endpoints" {
  description = "Map of VPC endpoint IDs"
  value = {
    ssm          = aws_vpc_endpoint.ssm.id
    ssm_messages = aws_vpc_endpoint.ssm_messages.id
    ec2_messages = aws_vpc_endpoint.ec2_messages.id
    logs         = var.enable_session_logging ? aws_vpc_endpoint.logs[0].id : null
  }
}

output "session_log_group_name" {
  description = "Name of the CloudWatch log group for SSM sessions"
  value       = var.enable_session_logging ? aws_cloudwatch_log_group.bastion_sessions[0].name : null
}

output "ssm_document_name" {
  description = "Name of the SSM document for session preferences"
  value       = var.enable_session_logging ? aws_ssm_document.bastion_session_preferences[0].name : null
}
