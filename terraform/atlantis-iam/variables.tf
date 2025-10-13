# ============================================
# Variables for Atlantis IAM Configuration
# ============================================

variable "atlantis_task_role_name" {
  description = "Name of the Atlantis ECS Task Role"
  type        = string
  default     = "atlantis-task-role"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "infrastructure"
    ManagedBy = "terraform"
  }
}
