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
# Tags
# ========================================

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
