# --- Required Variables ---

variable "aliases" {
  description = "List of CNAMEs (alternate domain names) for the distribution"
  type        = list(string)
  default     = []
}

variable "comment" {
  description = "Comment for the CloudFront distribution"
  type        = string

  validation {
    condition     = length(var.comment) > 0 && length(var.comment) <= 128
    error_message = "Comment must be between 1 and 128 characters."
  }
}

variable "origins" {
  description = "Configuration for one or more origins"
  type = map(object({
    domain_name = string
    origin_id   = string
    origin_path = optional(string, "")

    # S3 Origin Config
    s3_origin_config = optional(object({
      origin_access_identity = string
    }))

    # Custom Origin Config
    custom_origin_config = optional(object({
      http_port                = optional(number, 80)
      https_port               = optional(number, 443)
      origin_protocol_policy   = optional(string, "https-only")
      origin_ssl_protocols     = optional(list(string), ["TLSv1.2"])
      origin_keepalive_timeout = optional(number, 5)
      origin_read_timeout      = optional(number, 30)
    }))

    # Custom Headers
    custom_headers = optional(map(string), {})
  }))

  validation {
    condition     = length(var.origins) > 0
    error_message = "At least one origin must be specified."
  }
}

# --- Required Variables (Tagging) ---

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
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
  default     = "public"

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

# --- Optional Variables (Distribution Configuration) ---

variable "default_cache_behavior" {
  description = "Default cache behavior configuration"
  type = object({
    target_origin_id       = string
    viewer_protocol_policy = optional(string, "redirect-to-https")
    allowed_methods        = optional(list(string), ["GET", "HEAD", "OPTIONS"])
    cached_methods         = optional(list(string), ["GET", "HEAD"])
    compress               = optional(bool, true)
    default_ttl            = optional(number, 3600)
    max_ttl                = optional(number, 86400)
    min_ttl                = optional(number, 0)

    forwarded_values = optional(object({
      query_string = optional(bool, false)
      headers      = optional(list(string), [])
      cookies = optional(object({
        forward           = optional(string, "none")
        whitelisted_names = optional(list(string), [])
      }), {})
    }), {})

    function_associations = optional(list(object({
      event_type   = string
      function_arn = string
    })), [])

    lambda_function_associations = optional(list(object({
      event_type   = string
      lambda_arn   = string
      include_body = optional(bool, false)
    })), [])
  })
}

variable "default_root_object" {
  description = "Object that CloudFront returns when a viewer requests the root URL"
  type        = string
  default     = "index.html"
}

variable "enabled" {
  description = "Whether the distribution is enabled"
  type        = bool
  default     = true
}

variable "http_version" {
  description = "Maximum HTTP version to support (http1.1, http2, http2and3, or http3)"
  type        = string
  default     = "http2"

  validation {
    condition     = contains(["http1.1", "http2", "http2and3", "http3"], var.http_version)
    error_message = "HTTP version must be one of: http1.1, http2, http2and3, http3."
  }
}

variable "is_ipv6_enabled" {
  description = "Whether IPv6 is enabled for the distribution"
  type        = bool
  default     = true
}

variable "price_class" {
  description = "Price class for the distribution (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "Price class must be one of: PriceClass_All, PriceClass_200, PriceClass_100."
  }
}

variable "retain_on_delete" {
  description = "Disables the distribution instead of deleting it when destroying the resource"
  type        = bool
  default     = false
}

variable "wait_for_deployment" {
  description = "Wait for the distribution to be deployed before completing"
  type        = bool
  default     = true
}

# --- Optional Variables (Cache Behaviors) ---

variable "ordered_cache_behaviors" {
  description = "Ordered list of cache behaviors"
  type = list(object({
    path_pattern           = string
    target_origin_id       = string
    viewer_protocol_policy = optional(string, "redirect-to-https")
    allowed_methods        = optional(list(string), ["GET", "HEAD", "OPTIONS"])
    cached_methods         = optional(list(string), ["GET", "HEAD"])
    compress               = optional(bool, true)
    default_ttl            = optional(number, 3600)
    max_ttl                = optional(number, 86400)
    min_ttl                = optional(number, 0)

    forwarded_values = optional(object({
      query_string = optional(bool, false)
      headers      = optional(list(string), [])
      cookies = optional(object({
        forward           = optional(string, "none")
        whitelisted_names = optional(list(string), [])
      }), {})
    }), {})

    function_associations = optional(list(object({
      event_type   = string
      function_arn = string
    })), [])

    lambda_function_associations = optional(list(object({
      event_type   = string
      lambda_arn   = string
      include_body = optional(bool, false)
    })), [])
  }))
  default = []
}

# --- Optional Variables (Custom Error Response) ---

variable "custom_error_responses" {
  description = "Custom error response configuration"
  type = list(object({
    error_code            = number
    response_code         = optional(number)
    response_page_path    = optional(string)
    error_caching_min_ttl = optional(number, 300)
  }))
  default = []
}

# --- Optional Variables (Logging) ---

variable "logging_config" {
  description = "Logging configuration for the distribution"
  type = object({
    bucket          = string
    include_cookies = optional(bool, false)
    prefix          = optional(string, "")
  })
  default = null
}

# --- Optional Variables (Restrictions) ---

variable "geo_restriction" {
  description = "Geographic restriction configuration"
  type = object({
    restriction_type = string
    locations        = optional(list(string), [])
  })
  default = {
    restriction_type = "none"
    locations        = []
  }

  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction.restriction_type)
    error_message = "Restriction type must be one of: none, whitelist, blacklist."
  }
}

# --- Optional Variables (SSL/TLS) ---

variable "viewer_certificate" {
  description = "SSL/TLS certificate configuration"
  type = object({
    acm_certificate_arn            = optional(string)
    cloudfront_default_certificate = optional(bool, true)
    minimum_protocol_version       = optional(string, "TLSv1.2_2021")
    ssl_support_method             = optional(string, "sni-only")
  })
  default = {
    cloudfront_default_certificate = true
  }

  validation {
    condition = (
      var.viewer_certificate.acm_certificate_arn != null ? var.viewer_certificate.cloudfront_default_certificate == false : true
    )
    error_message = "When using ACM certificate, cloudfront_default_certificate must be false."
  }
}

# --- Optional Variables (WAF) ---

variable "web_acl_id" {
  description = "AWS WAF web ACL ARN to associate with the distribution"
  type        = string
  default     = null
}
