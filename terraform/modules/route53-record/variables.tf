# Variables for Route53 Record Module

variable "zone_id" {
  description = "The ID of the hosted zone to create the record in"
  type        = string
}

variable "name" {
  description = "The name of the DNS record (e.g., 'www', 'api', or 'subdomain.example.com')"
  type        = string
}

variable "type" {
  description = "The record type (A, AAAA, CNAME, MX, TXT, etc.)"
  type        = string
  validation {
    condition     = contains(["A", "AAAA", "CNAME", "MX", "TXT", "NS", "SRV", "PTR", "SPF", "CAA"], var.type)
    error_message = "Record type must be one of: A, AAAA, CNAME, MX, TXT, NS, SRV, PTR, SPF, CAA"
  }
}

variable "ttl" {
  description = "The TTL of the record in seconds (not used for alias records)"
  type        = number
  default     = 300
}

variable "records" {
  description = "List of DNS record values (not used for alias records)"
  type        = list(string)
  default     = null
}

variable "alias_configuration" {
  description = "Alias configuration for AWS resource records (ALB, CloudFront, etc.)"
  type = object({
    name                   = string
    zone_id                = string
    evaluate_target_health = bool
  })
  default = null
}

variable "weighted_routing_policy" {
  description = "Weighted routing policy configuration"
  type = object({
    weight = number
  })
  default = null
}

variable "geolocation_routing_policy" {
  description = "Geolocation routing policy configuration"
  type = object({
    continent   = optional(string)
    country     = optional(string)
    subdivision = optional(string)
  })
  default = null
}

variable "failover_routing_policy" {
  description = "Failover routing policy configuration (PRIMARY or SECONDARY)"
  type = object({
    type = string
  })
  default = null
  validation {
    condition     = var.failover_routing_policy == null || contains(["PRIMARY", "SECONDARY"], var.failover_routing_policy.type)
    error_message = "Failover type must be either PRIMARY or SECONDARY"
  }
}

variable "set_identifier" {
  description = "Unique identifier for routing policy records"
  type        = string
  default     = null
}

variable "health_check_id" {
  description = "The ID of the health check to associate with this record"
  type        = string
  default     = null
}

variable "allow_overwrite" {
  description = "Allow overwriting existing records with the same name"
  type        = bool
  default     = false
}
