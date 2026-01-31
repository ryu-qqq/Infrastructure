# ========================================
# Required Variables
# ========================================

variable "name" {
  description = "Name of the EventBridge rule"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "Name must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "target_type" {
  description = "Type of target (ecs, lambda, sns, sqs)"
  type        = string

  validation {
    condition     = contains(["ecs", "lambda", "sns", "sqs"], var.target_type)
    error_message = "Target type must be one of: ecs, lambda, sns, sqs."
  }
}

# ========================================
# Rule Configuration
# ========================================

variable "description" {
  description = "Description of the EventBridge rule"
  type        = string
  default     = ""
}

variable "schedule_expression" {
  description = "Schedule expression (cron or rate). Example: 'rate(5 minutes)' or 'cron(0 12 * * ? *)'"
  type        = string
  default     = null
}

variable "event_pattern" {
  description = "Event pattern JSON string for event-based rules"
  type        = string
  default     = null
}

variable "enabled" {
  description = "Whether the rule is enabled"
  type        = bool
  default     = true
}

# ========================================
# ECS Target Configuration
# ========================================

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster (required for ECS target)"
  type        = string
  default     = null
}

variable "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition (required for ECS target)"
  type        = string
  default     = null
}

variable "ecs_task_count" {
  description = "Number of tasks to run"
  type        = number
  default     = 1
}

variable "ecs_launch_type" {
  description = "Launch type for ECS task (FARGATE or EC2)"
  type        = string
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "EC2"], var.ecs_launch_type)
    error_message = "Launch type must be FARGATE or EC2."
  }
}

variable "ecs_network_configuration" {
  description = "Network configuration for ECS task"
  type = object({
    subnets          = list(string)
    security_groups  = list(string)
    assign_public_ip = bool
  })
  default = null
}

variable "ecs_task_role_arns" {
  description = "List of IAM role ARNs that EventBridge can pass to ECS tasks"
  type        = list(string)
  default     = []
}

# ========================================
# Lambda Target Configuration
# ========================================

variable "lambda_function_arn" {
  description = "ARN of the Lambda function (required for Lambda target)"
  type        = string
  default     = null
}

variable "lambda_function_name" {
  description = "Name of the Lambda function (required for Lambda target)"
  type        = string
  default     = null
}

# ========================================
# SNS Target Configuration
# ========================================

variable "sns_topic_arn" {
  description = "ARN of the SNS topic (required for SNS target)"
  type        = string
  default     = null
}

# ========================================
# SQS Target Configuration
# ========================================

variable "sqs_queue_arn" {
  description = "ARN of the SQS queue (required for SQS target)"
  type        = string
  default     = null
}

# ========================================
# Required Variables (Tagging)
# ========================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, staging, prod."
  }
}

variable "service_name" {
  description = "Service name (kebab-case, e.g., event-processor)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "team" {
  description = "Team responsible for the resource (kebab-case, e.g., platform-team)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.team))
    error_message = "Team must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "owner" {
  description = "Email or identifier of the resource owner"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner)) || can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.owner))
    error_message = "Owner must be a valid email address or kebab-case identifier."
  }
}

variable "cost_center" {
  description = "Cost center for billing and financial tracking (kebab-case)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cost_center))
    error_message = "Cost center must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

# ========================================
# Optional Variables (Tagging)
# ========================================

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

variable "additional_tags" {
  description = "Additional tags to merge with common tags"
  type        = map(string)
  default     = {}
}
