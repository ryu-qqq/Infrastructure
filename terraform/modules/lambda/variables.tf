# Lambda Function Module Variables

# Required Tags Variables
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "service" {
  description = "Service name"
  type        = string
}

variable "team" {
  description = "Team responsible for the resource"
  type        = string
}

variable "owner" {
  description = "Owner email address"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}

variable "project" {
  description = "Project name this resource belongs to"
  type        = string
  default     = "infrastructure"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project))
    error_message = "Project must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "data_class" {
  description = "Data classification level (confidential, internal, public)"
  type        = string
  default     = "confidential"

  validation {
    condition     = contains(["confidential", "internal", "public"], var.data_class)
    error_message = "Data class must be one of: confidential, internal, public."
  }
}

# Lambda Function Configuration
variable "name" {
  description = "Lambda function name suffix (will be prefixed with service-environment)"
  type        = string
}

variable "function_name" {
  description = "Full Lambda function name (overrides auto-generated name)"
  type        = string
  default     = ""
}

variable "description" {
  description = "Description of the Lambda function"
  type        = string
  default     = ""
}

variable "handler" {
  description = "Lambda function handler (e.g., index.handler, lambda_function.lambda_handler)"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime (e.g., python3.11, nodejs20.x)"
  type        = string

  validation {
    condition = contains([
      "python3.9", "python3.10", "python3.11", "python3.12",
      "nodejs18.x", "nodejs20.x",
      "java17", "java21",
      "dotnet6", "dotnet8",
      "go1.x",
      "ruby3.2", "ruby3.3"
    ], var.runtime)
    error_message = "Runtime must be a valid AWS Lambda runtime"
  }
}

variable "architectures" {
  description = "Instruction set architecture (x86_64 or arm64)"
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition     = alltrue([for arch in var.architectures : contains(["x86_64", "arm64"], arch)])
    error_message = "Architectures must be x86_64 or arm64"
  }
}

variable "timeout" {
  description = "Function timeout in seconds (1-900)"
  type        = number
  default     = 30

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds"
  }
}

variable "memory_size" {
  description = "Memory size in MB (128-10240)"
  type        = number
  default     = 128

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Memory size must be between 128 and 10240 MB"
  }
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions (-1 for unreserved)"
  type        = number
  default     = -1
}

# Code Deployment
variable "filename" {
  description = "Path to the function's deployment package (local file)"
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the function's deployment package"
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key of the function's deployment package"
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "Object version of the function's deployment package"
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the package file"
  type        = string
  default     = null
}

variable "layers" {
  description = "List of Lambda Layer ARNs"
  type        = list(string)
  default     = []
}

variable "publish" {
  description = "Whether to publish creation/change as new Lambda Function Version"
  type        = bool
  default     = false
}

# Environment Variables
variable "environment_variables" {
  description = "Map of environment variables"
  type        = map(string)
  default     = null
}

# VPC Configuration
variable "vpc_config" {
  description = "VPC configuration for Lambda function"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

# IAM Configuration
variable "create_role" {
  description = "Whether to create IAM role for Lambda function"
  type        = bool
  default     = true
}

variable "lambda_role_arn" {
  description = "Existing IAM role ARN (required if create_role is false)"
  type        = string
  default     = null
}

variable "custom_policy_arns" {
  description = "Map of custom IAM policy ARNs to attach to Lambda role"
  type        = map(string)
  default     = {}
}

variable "inline_policy" {
  description = "Inline IAM policy JSON document"
  type        = string
  default     = null
}

# CloudWatch Logs
variable "create_log_group" {
  description = "Whether to create CloudWatch Log Group"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 14

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch Logs retention value"
  }
}

variable "log_kms_key_id" {
  description = "KMS key ID for CloudWatch Logs encryption"
  type        = string
  default     = null
}

# Dead Letter Queue
variable "create_dlq" {
  description = "Whether to create Dead Letter Queue"
  type        = bool
  default     = false
}

variable "dlq_message_retention_seconds" {
  description = "DLQ message retention in seconds (60-1209600)"
  type        = number
  default     = 1209600

  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "DLQ message retention must be between 60 and 1209600 seconds"
  }
}

variable "dlq_kms_key_id" {
  description = "KMS key ID for DLQ encryption"
  type        = string
  default     = null
}

variable "dlq_visibility_timeout_seconds" {
  description = "DLQ visibility timeout in seconds (0-43200)"
  type        = number
  default     = 300

  validation {
    condition     = var.dlq_visibility_timeout_seconds >= 0 && var.dlq_visibility_timeout_seconds <= 43200
    error_message = "DLQ visibility timeout must be between 0 and 43200 seconds."
  }
}

# Tracing
variable "tracing_mode" {
  description = "X-Ray tracing mode (Active or PassThrough)"
  type        = string
  default     = null

  validation {
    condition     = var.tracing_mode == null ? true : contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "Tracing mode must be Active or PassThrough"
  }
}

# Ephemeral Storage
variable "ephemeral_storage_size" {
  description = "Ephemeral storage size in MB (512-10240)"
  type        = number
  default     = null

  validation {
    condition     = var.ephemeral_storage_size == null ? true : (var.ephemeral_storage_size >= 512 && var.ephemeral_storage_size <= 10240)
    error_message = "Ephemeral storage size must be between 512 and 10240 MB"
  }
}

# Aliases
variable "aliases" {
  description = "Map of Lambda function aliases"
  type = map(object({
    description      = string
    function_version = string
    routing_config = optional(object({
      additional_version_weights = map(number)
    }))
  }))
  default = {}
}

# Lambda Permissions
variable "lambda_permissions" {
  description = "Map of Lambda permission configurations"
  type = map(object({
    action     = string
    principal  = string
    source_arn = optional(string)
    qualifier  = optional(string)
  }))
  default = {}
}

# Additional Tags
variable "additional_tags" {
  description = "Additional tags to merge with common tags"
  type        = map(string)
  default     = {}
}
