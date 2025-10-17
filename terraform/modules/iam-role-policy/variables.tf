# --- Required Variables ---

variable "role_name" {
  description = "Name of the IAM role to create"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_+=,.@]+$", var.role_name)) && length(var.role_name) <= 64
    error_message = "Role name must contain only valid IAM characters and be 64 characters or less."
  }
}

variable "assume_role_policy" {
  description = "JSON policy document for the assume role policy"
  type        = string
}

# --- Optional Variables (Role Configuration) ---

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "description" {
  description = "Description of the IAM role"
  type        = string
  default     = ""
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds (3600-43200)"
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Max session duration must be between 3600 and 43200 seconds."
  }
}

variable "permissions_boundary" {
  description = "ARN of the policy that is used to set the permissions boundary for the role"
  type        = string
  default     = null
}

# --- Policy Attachment Variables ---

variable "attach_aws_managed_policies" {
  description = "List of AWS managed policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

# --- ECS Task Policy Variables ---

variable "enable_ecs_task_execution_policy" {
  description = "Enable standard ECS task execution policy (ECR, CloudWatch Logs)"
  type        = bool
  default     = false
}

variable "enable_ecs_task_policy" {
  description = "Enable ECS task role policy with basic permissions"
  type        = bool
  default     = false
}

variable "ecs_cluster_arns" {
  description = "List of ECS cluster ARNs to restrict DescribeTasks and ListTasks permissions"
  type        = list(string)
  default     = []
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs for image pull permissions"
  type        = list(string)
  default     = []
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs for decryption permissions"
  type        = list(string)
  default     = []
}

# --- RDS Policy Variables ---

variable "enable_rds_policy" {
  description = "Enable RDS access policy"
  type        = bool
  default     = false
}

variable "rds_cluster_arns" {
  description = "List of RDS cluster ARNs for database access"
  type        = list(string)
  default     = []
}

variable "rds_db_instance_arns" {
  description = "List of RDS DB instance ARNs for database access"
  type        = list(string)
  default     = []
}

variable "rds_iam_db_user_arns" {
  description = "List of RDS DB user ARNs for IAM database authentication (format: arn:aws:rds-db:region:account:dbuser:db-resource-id/db-username)"
  type        = list(string)
  default     = []
}

# --- Secrets Manager Policy Variables ---

variable "enable_secrets_manager_policy" {
  description = "Enable Secrets Manager access policy"
  type        = bool
  default     = false
}

variable "secrets_manager_secret_arns" {
  description = "List of Secrets Manager secret ARNs for read access"
  type        = list(string)
  default     = []
}

variable "secrets_manager_allow_create" {
  description = "Allow creating new secrets"
  type        = bool
  default     = false
}

variable "secrets_manager_allow_update" {
  description = "Allow updating existing secrets"
  type        = bool
  default     = false
}

variable "secrets_manager_allow_delete" {
  description = "Allow deleting secrets"
  type        = bool
  default     = false
}

# --- S3 Policy Variables ---

variable "enable_s3_policy" {
  description = "Enable S3 access policy"
  type        = bool
  default     = false
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs for access (bucket level)"
  type        = list(string)
  default     = []
}

variable "s3_object_arns" {
  description = "List of S3 object ARNs for access (object level, typically bucket_arn/*)"
  type        = list(string)
  default     = []
}

variable "s3_allow_write" {
  description = "Allow write operations to S3 (PutObject, DeleteObject)"
  type        = bool
  default     = false
}

variable "s3_allow_list" {
  description = "Allow listing objects in S3 buckets"
  type        = bool
  default     = true
}

# --- CloudWatch Logs Policy Variables ---

variable "enable_cloudwatch_logs_policy" {
  description = "Enable CloudWatch Logs access policy"
  type        = bool
  default     = false
}

variable "cloudwatch_log_group_arns" {
  description = "List of CloudWatch Log Group ARNs for write access"
  type        = list(string)
  default     = []
}

variable "cloudwatch_allow_create_log_group" {
  description = "Allow creating new log groups"
  type        = bool
  default     = true
}

# --- Custom Inline Policy Variables ---

variable "custom_inline_policies" {
  description = "Map of custom inline policies to attach to the role"
  type = map(object({
    policy = string
  }))
  default = {}
}
