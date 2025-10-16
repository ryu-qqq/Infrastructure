variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "ap-northeast-2"
}

variable "vpc_id" {
  description = "The ID of the VPC where RDS will be deployed"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "service_name" {
  description = "Name of the service using this RDS instance"
  type        = string
  default     = "myapp"
}

variable "instance_class" {
  description = "The instance type of the RDS instance"
  type        = string
  default     = "db.r5.large"
}

variable "allocated_storage" {
  description = "The allocated storage in gigabytes"
  type        = number
  default     = 100
}

variable "max_allocated_storage" {
  description = "The upper limit for storage autoscaling"
  type        = number
  default     = 500
}

variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "If true, the database cannot be deleted"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "The name of the database to create"
  type        = string
  default     = "production"
}

variable "master_username" {
  description = "Username for the master DB user"
  type        = string
  default     = "pgadmin"
}

variable "master_password" {
  description = "Password for the master DB user (minimum 8 characters)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.master_password) >= 8
    error_message = "Master password must be at least 8 characters long"
  }
}
