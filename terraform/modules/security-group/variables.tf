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

# --- Optional Variables ---

variable "description" {
  description = "Description of the security group"
  type        = string
  default     = "Managed by Terraform"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
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
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_block      = optional(string)
    ipv6_cidr_block = optional(string)
    description     = optional(string)
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
