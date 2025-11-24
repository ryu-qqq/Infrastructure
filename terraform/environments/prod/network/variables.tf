# Variables for Network Infrastructure

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

# Required Tag Variables (governance compliance)

variable "service_name" {
  description = "Service name for resource naming and Service tag"
  type        = string
  default     = "network"
}

variable "team" {
  description = "Team responsible for the resources (Owner tag)"
  type        = string
  default     = "platform-team"
}

variable "project" {
  description = "Project name (Component tag)"
  type        = string
  default     = "shared-infrastructure"
}

variable "cost_center" {
  description = "Cost center for billing (CostCenter tag)"
  type        = string
  default     = "infrastructure"
}

variable "data_class" {
  description = "Data classification level (DataClass tag)"
  type        = string
  default     = "internal"
}

variable "lifecycle_stage" {
  description = "Lifecycle stage (Lifecycle tag)"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# Transit Gateway Variables

variable "enable_transit_gateway" {
  description = "Enable Transit Gateway for multi-VPC communication"
  type        = bool
  default     = true
}

variable "transit_gateway_asn" {
  description = "Amazon side ASN for Transit Gateway"
  type        = number
  default     = 64512
}

variable "transit_gateway_routes" {
  description = "List of CIDR blocks to route through Transit Gateway (for future VPCs)"
  type        = list(string)
  default     = []
  # Example: ["10.1.0.0/16", "10.2.0.0/16"] for additional VPCs
}
