# --- Required Variables ---

variable "name" {
  description = "Name of the security group"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name)) && length(var.name) <= 255
    error_message = "Security group name must be kebab-case (lowercase letters, numbers, hyphens) and 255 characters or less."
  }
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created"
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

# --- Optional Variables ---

variable "description" {
  description = "Description of the security group"
  type        = string
  default     = "Managed by Terraform"
}

# --- Security Group Type Configuration ---

variable "type" {
  description = "Type of security group (alb, ecs, rds, vpc-endpoint, custom)"
  type        = string
  default     = "custom"

  validation {
    condition     = contains(["alb", "ecs", "rds", "vpc-endpoint", "custom"], var.type)
    error_message = "Type must be one of: alb, ecs, rds, vpc-endpoint, custom."
  }
}

# --- ALB Security Group Configuration ---

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB on HTTP/HTTPS ports"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_http_port" {
  description = "HTTP port for ALB"
  type        = number
  default     = 80
}

variable "alb_https_port" {
  description = "HTTPS port for ALB"
  type        = number
  default     = 443
}

variable "alb_enable_http" {
  description = "Enable HTTP ingress rule for ALB"
  type        = bool
  default     = true
}

variable "alb_enable_https" {
  description = "Enable HTTPS ingress rule for ALB"
  type        = bool
  default     = true
}

# --- ECS Security Group Configuration ---

variable "enable_ecs_alb_ingress" {
  description = "Enable ingress rule from ALB to ECS (set to true when ecs_ingress_from_alb_sg_id is provided)"
  type        = bool
  default     = false
}

variable "ecs_ingress_from_alb_sg_id" {
  description = "ALB security group ID to allow ingress to ECS"
  type        = string
  default     = null
}

variable "ecs_container_port" {
  description = "Container port for ECS service"
  type        = number
  default     = 8080
}

variable "ecs_additional_ingress_sg_ids" {
  description = "Additional security group IDs to allow ingress to ECS"
  type        = list(string)
  default     = []
}

# --- RDS Security Group Configuration ---

variable "enable_rds_ecs_ingress" {
  description = "Enable ingress rule from ECS to RDS (set to true when rds_ingress_from_ecs_sg_id is provided)"
  type        = bool
  default     = false
}

variable "rds_ingress_from_ecs_sg_id" {
  description = "ECS security group ID to allow ingress to RDS"
  type        = string
  default     = null
}

variable "rds_port" {
  description = "Database port for RDS"
  type        = number
  default     = 5432
}

variable "rds_additional_ingress_sg_ids" {
  description = "Additional security group IDs to allow ingress to RDS"
  type        = list(string)
  default     = []
}

variable "rds_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access RDS (use with caution)"
  type        = list(string)
  default     = []
}

# --- VPC Endpoint Security Group Configuration ---

variable "vpc_endpoint_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access VPC endpoints"
  type        = list(string)
  default     = []
}

variable "vpc_endpoint_ingress_sg_ids" {
  description = "Security group IDs allowed to access VPC endpoints"
  type        = list(string)
  default     = []
}

variable "vpc_endpoint_port" {
  description = "Port for VPC endpoint"
  type        = number
  default     = 443
}

# --- Custom Ingress Rules ---

variable "custom_ingress_rules" {
  description = "List of custom ingress rules"
  type = list(object({
    from_port                = number
    to_port                  = number
    protocol                 = string
    cidr_block               = optional(string)
    ipv6_cidr_block          = optional(string)
    source_security_group_id = optional(string)
    description              = optional(string)
  }))
  default = []
}

# --- Custom Egress Rules ---

variable "custom_egress_rules" {
  description = "List of custom egress rules"
  type = list(object({
    from_port                     = number
    to_port                       = number
    protocol                      = string
    cidr_block                    = optional(string)
    ipv6_cidr_block               = optional(string)
    destination_security_group_id = optional(string)
    description                   = optional(string)
  }))
  default = []
}

variable "enable_default_egress" {
  description = "Enable default egress rule (allow all outbound traffic)"
  type        = bool
  default     = true
}

# --- Revoke Rules on Delete ---

variable "revoke_rules_on_delete" {
  description = "Instruct Terraform to revoke all rules in the security group before deleting the group itself"
  type        = bool
  default     = false
}
