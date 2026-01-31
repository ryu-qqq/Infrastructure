# ============================================================================
# Required Variables
# ============================================================================

variable "assume_role_policy" {
  description = "JSON policy document for the assume role policy (typically ECS tasks service principal)"
  type        = string

  # Default ECS tasks assume role policy if not provided
  default = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ecs-tasks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
  EOF
}

variable "role_name" {
  description = "Name of the IAM role to create (kebab-case)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.role_name)) && length(var.role_name) <= 64
    error_message = "Role name must be kebab-case (lowercase letters, numbers, hyphens) and 64 characters or less."
  }
}

# ============================================================================
# Required Variables (Tagging)
# ============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, staging, prod."
  }
}

variable "service_name" {
  description = "Service name (kebab-case, e.g., api-server, web-app)"
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

# ============================================================================
# Optional Variables (Tagging)
# ============================================================================

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
  default     = "internal"

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

# ============================================================================
# Optional Variables (Role Configuration)
# ============================================================================

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

# ============================================================================
# Policy Attachment Variables
# ============================================================================

variable "attach_aws_managed_policies" {
  description = "List of AWS managed policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

# ============================================================================
# Observability Policy Variables
# ============================================================================

variable "enable_xray_policy" {
  description = "Enable X-Ray tracing policy (PutTraceSegments, GetSamplingRules, etc.)"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs_policy" {
  description = "Enable CloudWatch Logs policy for OTEL collector"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_metrics_policy" {
  description = "Enable CloudWatch Metrics policy for Micrometer/OTEL"
  type        = bool
  default     = true
}

variable "enable_combined_observability_policy" {
  description = "Enable combined observability policy (X-Ray + CloudWatch Logs + Metrics in single policy). When true, individual policies are ignored."
  type        = bool
  default     = false
}

# ============================================================================
# CloudWatch Logs Configuration
# ============================================================================

variable "cloudwatch_allow_create_log_group" {
  description = "Allow creating new CloudWatch log groups"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_arns" {
  description = "List of CloudWatch Log Group ARNs for write access (e.g., OTEL collector logs)"
  type        = list(string)
  default     = []
}

variable "cloudwatch_log_group_prefixes" {
  description = "List of CloudWatch Log Group prefixes for CreateLogGroup permission (e.g., /ecs/myservice/)"
  type        = list(string)
  default     = []
}

# ============================================================================
# CloudWatch Metrics Configuration
# ============================================================================

variable "cloudwatch_metric_namespaces" {
  description = "List of CloudWatch metric namespaces allowed for PutMetricData (e.g., [\"FileFlow\", \"MyService\"]). Empty list allows all namespaces."
  type        = list(string)
  default     = []
}

# ============================================================================
# Custom Inline Policy Variables
# ============================================================================

variable "custom_inline_policies" {
  description = "Map of custom inline policies to attach to the role"
  type = map(object({
    policy = string
  }))
  default = {}
}
