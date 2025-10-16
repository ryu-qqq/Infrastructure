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
  default     = "dev"

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

variable "db_name" {
  description = "The name of the database to create"
  type        = string
  default     = "myappdb"
}

variable "master_username" {
  description = "Username for the master DB user"
  type        = string
  default     = "dbadmin"
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
