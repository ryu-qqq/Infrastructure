# Variables for Network Infrastructure

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
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
