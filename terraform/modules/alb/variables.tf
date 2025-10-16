# --- Required Variables ---

variable "name" {
  description = "Name of the Application Load Balancer"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.name)) && length(var.name) <= 32
    error_message = "Name must contain only alphanumeric characters and hyphens, and be 32 characters or less."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB. Must span at least 2 availability zones."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets in different availability zones are required for high availability."
  }
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created"
  type        = string

  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "VPC ID must start with 'vpc-'."
  }
}

# --- Optional Variables (ALB Configuration) ---

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = false
}

variable "enable_http2" {
  description = "Enable HTTP/2 on the ALB"
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "Time in seconds that connections are allowed to be idle"
  type        = number
  default     = 60

  validation {
    condition     = var.idle_timeout >= 1 && var.idle_timeout <= 4000
    error_message = "Idle timeout must be between 1 and 4000 seconds."
  }
}

variable "internal" {
  description = "Whether the ALB is internal or internet-facing"
  type        = bool
  default     = false
}

variable "ip_address_type" {
  description = "Type of IP addresses used by subnets for the ALB (ipv4 or dualstack)"
  type        = string
  default     = "ipv4"

  validation {
    condition     = contains(["ipv4", "dualstack"], var.ip_address_type)
    error_message = "IP address type must be either 'ipv4' or 'dualstack'."
  }
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the ALB"
  type        = list(string)
  default     = []
}

# --- Optional Variables (Target Group) ---

variable "target_groups" {
  description = "Map of target group configurations"
  type = map(object({
    port                 = number
    protocol             = optional(string, "HTTP")
    target_type          = optional(string, "ip")
    deregistration_delay = optional(number, 300)

    health_check = optional(object({
      enabled             = optional(bool, true)
      healthy_threshold   = optional(number, 3)
      interval            = optional(number, 30)
      matcher             = optional(string, "200")
      path                = optional(string, "/health")
      protocol            = optional(string, "HTTP")
      timeout             = optional(number, 5)
      unhealthy_threshold = optional(number, 2)
    }), {})

    stickiness = optional(object({
      enabled         = optional(bool, false)
      type            = optional(string, "lb_cookie")
      cookie_duration = optional(number, 86400)
    }), {})
  }))
  default = {}
}

# --- Optional Variables (Listeners) ---

variable "http_listeners" {
  description = "Map of HTTP listener configurations"
  type = map(object({
    port     = optional(number, 80)
    protocol = optional(string, "HTTP")

    default_action = object({
      type             = string
      target_group_key = optional(string)
      redirect = optional(object({
        port        = string
        protocol    = string
        status_code = string
      }))
      fixed_response = optional(object({
        content_type = string
        message_body = optional(string)
        status_code  = string
      }))
    })
  }))
  default = {}
}

variable "https_listeners" {
  description = "Map of HTTPS listener configurations"
  type = map(object({
    port            = optional(number, 443)
    protocol        = optional(string, "HTTPS")
    certificate_arn = string
    ssl_policy      = optional(string, "ELBSecurityPolicy-TLS13-1-2-2021-06")

    default_action = object({
      type             = string
      target_group_key = optional(string)
      fixed_response = optional(object({
        content_type = string
        message_body = optional(string)
        status_code  = string
      }))
    })
  }))
  default = {}
}

# --- Optional Variables (Listener Rules) ---

variable "listener_rules" {
  description = "Map of listener rule configurations for path-based routing"
  type = map(object({
    listener_key = string
    priority     = number

    conditions = list(object({
      path_pattern = optional(list(string))
      host_header  = optional(list(string))
    }))

    actions = list(object({
      type             = string
      target_group_key = optional(string)
      redirect = optional(object({
        port        = optional(string)
        protocol    = optional(string)
        status_code = string
        host        = optional(string)
        path        = optional(string)
      }))
      fixed_response = optional(object({
        content_type = string
        message_body = optional(string)
        status_code  = string
      }))
    }))
  }))
  default = {}
}

# --- Optional Variables (Access Logs) ---

variable "access_logs" {
  description = "Access logs configuration for the ALB"
  type = object({
    bucket  = string
    enabled = optional(bool, true)
    prefix  = optional(string)
  })
  default = null
}
