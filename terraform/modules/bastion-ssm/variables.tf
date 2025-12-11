# ============================================================================
# Bastion SSM Module - Input Variables
# ============================================================================

# Required Variables

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where bastion will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for bastion instance (should be private subnet)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources (should include required governance tags)"
  type        = map(string)
}

# Optional Variables

variable "instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.nano"
}

variable "volume_size" {
  description = "Root volume size for bastion host (GB)"
  type        = number
  default     = 20
}

variable "enable_session_logging" {
  description = "Enable CloudWatch logging for SSM sessions"
  type        = bool
  default     = true
}

variable "session_log_retention_days" {
  description = "Retention period for bastion session logs (days)"
  type        = number
  default     = 30
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for VPC endpoints"
  type        = list(string)
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2 instance"
  type        = bool
  default     = true
}
