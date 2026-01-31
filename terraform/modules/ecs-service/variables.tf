# Required Variables

variable "cluster_id" {
  description = "The ID of the ECS cluster where the service will be deployed"
  type        = string
}

variable "container_image" {
  description = "The Docker image to use for the container (e.g., 'nginx:latest' or ECR repository URL)"
  type        = string
}

variable "container_name" {
  description = "The name of the container. Must match the name used in task definition"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.container_name))
    error_message = "Container name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "container_port" {
  description = "The port on which the container listens"
  type        = number

  validation {
    condition     = var.container_port > 0 && var.container_port < 65536
    error_message = "Container port must be between 1 and 65535"
  }
}

variable "cpu" {
  description = "The number of CPU units to reserve for the container (256, 512, 1024, 2048, 4096, 8192, 16384)"
  type        = number

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096, 8192, 16384"
  }
}

variable "desired_count" {
  description = "The desired number of tasks to run in the service"
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 0
    error_message = "Desired count must be greater than or equal to 0"
  }
}

variable "execution_role_arn" {
  description = "The ARN of the IAM role for ECS task execution (required for pulling images and accessing secrets)"
  type        = string
}

variable "memory" {
  description = "The amount of memory (in MiB) to reserve for the container"
  type        = number

  validation {
    condition     = var.memory > 0
    error_message = "Memory must be greater than 0"
  }
}

variable "name" {
  description = "The name of the ECS service (will be used in task definition family and service name)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the ECS tasks"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of subnet IDs where ECS tasks will be deployed"
  type        = list(string)
}

variable "task_role_arn" {
  description = "The ARN of the IAM role for ECS task (used by the container application)"
  type        = string
}

# --- Required Variables (Tagging) ---

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

# --- Optional Variables (Tagging) ---

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

# Optional Variables - Container Configuration

variable "container_environment" {
  description = "Environment variables to pass to the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "container_secrets" {
  description = "Secrets to pass to the container from AWS Secrets Manager or Parameter Store"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the ECS cluster"
  type        = bool
  default     = true
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for the service (allows SSH-like access to containers)"
  type        = bool
  default     = false
}

variable "health_check_command" {
  description = "The command to run for container health checks. If null, no health check is configured"
  type        = list(string)
  default     = null
}

variable "health_check_interval" {
  description = "Time in seconds between health checks (must be between 5 and 300)"
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds"
  }
}

variable "health_check_retries" {
  description = "Number of consecutive health check failures before marking the container unhealthy"
  type        = number
  default     = 3

  validation {
    condition     = var.health_check_retries >= 1 && var.health_check_retries <= 10
    error_message = "Health check retries must be between 1 and 10"
  }
}

variable "health_check_start_period" {
  description = "Grace period in seconds before health checks start (must be between 0 and 300)"
  type        = number
  default     = 60

  validation {
    condition     = var.health_check_start_period >= 0 && var.health_check_start_period <= 300
    error_message = "Health check start period must be between 0 and 300 seconds"
  }
}

variable "health_check_timeout" {
  description = "Timeout in seconds for health checks (must be between 2 and 60)"
  type        = number
  default     = 5

  validation {
    condition     = var.health_check_timeout >= 2 && var.health_check_timeout <= 60
    error_message = "Health check timeout must be between 2 and 60 seconds"
  }
}

# Optional Variables - Service Configuration

variable "assign_public_ip" {
  description = "Assign a public IP to the ENI (required if tasks are in public subnets without NAT)"
  type        = bool
  default     = false
}

variable "deployment_circuit_breaker_enable" {
  description = "Enable deployment circuit breaker to automatically roll back failed deployments"
  type        = bool
  default     = true
}

variable "deployment_circuit_breaker_rollback" {
  description = "Automatically roll back on deployment failure when circuit breaker is enabled"
  type        = bool
  default     = true
}

variable "deployment_maximum_percent" {
  description = "Maximum percentage of tasks allowed during deployment (100-200)"
  type        = number
  default     = 200

  validation {
    condition     = var.deployment_maximum_percent >= 100 && var.deployment_maximum_percent <= 200
    error_message = "Deployment maximum percent must be between 100 and 200"
  }
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percentage of tasks during deployment (0-100)"
  type        = number
  default     = 100

  validation {
    condition     = var.deployment_minimum_healthy_percent >= 0 && var.deployment_minimum_healthy_percent <= 100
    error_message = "Deployment minimum healthy percent must be between 0 and 100"
  }
}

variable "enable_ecs_managed_tags" {
  description = "Enable ECS managed tags for the service"
  type        = bool
  default     = true
}

variable "health_check_grace_period_seconds" {
  description = "Grace period in seconds for ALB health checks before tasks are marked unhealthy"
  type        = number
  default     = null
}

variable "load_balancer_config" {
  description = "Load balancer configuration. Set to null if not using a load balancer"
  type = object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  })
  default = null
}

variable "propagate_tags" {
  description = "Specifies whether to propagate tags from task definition or service (TASK_DEFINITION, SERVICE, or NONE)"
  type        = string
  default     = "SERVICE"

  validation {
    condition     = contains(["TASK_DEFINITION", "SERVICE", "NONE"], var.propagate_tags)
    error_message = "Propagate tags must be one of: TASK_DEFINITION, SERVICE, or NONE"
  }
}

# Optional Variables - Auto Scaling

variable "enable_autoscaling" {
  description = "Enable auto scaling for the ECS service"
  type        = bool
  default     = false
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks for auto scaling"
  type        = number
  default     = 4

  validation {
    condition     = var.autoscaling_max_capacity > 0
    error_message = "Auto scaling max capacity must be greater than 0"
  }
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of tasks for auto scaling"
  type        = number
  default     = 1

  validation {
    condition     = var.autoscaling_min_capacity >= 0
    error_message = "Auto scaling min capacity must be greater than or equal to 0"
  }
}

variable "autoscaling_target_cpu" {
  description = "Target CPU utilization percentage for auto scaling (1-100)"
  type        = number
  default     = 70

  validation {
    condition     = var.autoscaling_target_cpu >= 1 && var.autoscaling_target_cpu <= 100
    error_message = "Auto scaling target CPU must be between 1 and 100"
  }
}

variable "autoscaling_target_memory" {
  description = "Target memory utilization percentage for auto scaling (1-100)"
  type        = number
  default     = 80

  validation {
    condition     = var.autoscaling_target_memory >= 1 && var.autoscaling_target_memory <= 100
    error_message = "Auto scaling target memory must be between 1 and 100"
  }
}

# Optional Variables - Logging

variable "log_configuration" {
  description = "Log configuration for the container. If null, a default CloudWatch Logs configuration will be created"
  type = object({
    log_driver = string
    options    = map(string)
  })
  default = null
}

variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch Logs (if using default log configuration)"
  type        = number
  default     = 7

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention value"
  }
}

# Optional Variables - Sidecar Containers

variable "sidecars" {
  description = "List of sidecar container definitions to add to the task. Each sidecar should be a complete container definition object."
  type = list(object({
    name      = string
    image     = string
    cpu       = optional(number, 256)
    memory    = optional(number, 512)
    essential = optional(bool, false)
    command   = optional(list(string), [])
    portMappings = optional(list(object({
      containerPort = number
      protocol      = optional(string, "tcp")
      hostPort      = optional(number)
    })), [])
    environment = optional(list(object({
      name  = string
      value = string
    })), [])
    secrets = optional(list(object({
      name      = string
      valueFrom = string
    })), [])
    logConfiguration = optional(object({
      logDriver = string
      options   = map(string)
    }))
    healthCheck = optional(object({
      command     = list(string)
      interval    = optional(number, 30)
      timeout     = optional(number, 5)
      retries     = optional(number, 3)
      startPeriod = optional(number, 60)
    }))
    dependsOn = optional(list(object({
      containerName = string
      condition     = string
    })), [])
  }))
  default = []
}

# ============================================================================
# Service Discovery Configuration
# ============================================================================

variable "enable_service_discovery" {
  description = "Enable AWS Cloud Map service discovery for this ECS service"
  type        = bool
  default     = false
}

variable "service_discovery_namespace_id" {
  description = "Cloud Map namespace ID for service discovery. Required when enable_service_discovery is true"
  type        = string
  default     = null
}

variable "service_discovery_namespace_name" {
  description = "Cloud Map namespace name (e.g., connectly.local). Required when enable_service_discovery is true"
  type        = string
  default     = "connectly.local"
}

variable "service_discovery_dns_ttl" {
  description = <<-EOT
    TTL for DNS records in seconds.
    Lower values = faster failover, higher values = less DNS load.
    AWS Route 53 recommends 60-172,800 seconds (1 min - 2 days) for operational use.
    Default: 10 seconds (optimized for service discovery failover)
  EOT
  type        = number
  default     = 10

  validation {
    condition     = var.service_discovery_dns_ttl >= 0 && var.service_discovery_dns_ttl <= 172800
    error_message = "DNS TTL must be between 0 and 172,800 seconds (AWS recommended range)"
  }
}

variable "service_discovery_dns_type" {
  description = "DNS record type for service discovery (A for IP address, SRV for port+IP)"
  type        = string
  default     = "A"

  validation {
    condition     = contains(["A", "SRV"], var.service_discovery_dns_type)
    error_message = "DNS type must be either A or SRV"
  }
}

variable "service_discovery_routing_policy" {
  description = "Routing policy for service discovery (MULTIVALUE for load balancing, WEIGHTED for single instance)"
  type        = string
  default     = "MULTIVALUE"

  validation {
    condition     = contains(["MULTIVALUE", "WEIGHTED"], var.service_discovery_routing_policy)
    error_message = "Routing policy must be either MULTIVALUE or WEIGHTED"
  }
}

variable "service_discovery_failure_threshold" {
  description = "Number of consecutive health check failures before removing instance from DNS"
  type        = number
  default     = 1

  validation {
    condition     = var.service_discovery_failure_threshold >= 1 && var.service_discovery_failure_threshold <= 10
    error_message = "Failure threshold must be between 1 and 10"
  }
}

variable "service_discovery_endpoint_scheme" {
  description = "URL scheme for service discovery endpoint output (http, https, grpc, etc.)"
  type        = string
  default     = "http"

  validation {
    condition     = contains(["http", "https", "grpc", "grpcs"], var.service_discovery_endpoint_scheme)
    error_message = "Endpoint scheme must be one of: http, https, grpc, grpcs"
  }
}
