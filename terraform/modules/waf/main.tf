# ==============================================================================
# Local Values
# ==============================================================================

locals {
  metric_name = var.metric_name != null ? var.metric_name : var.name

  # Managed rule groups
  managed_rule_groups = concat(
    var.enable_owasp_rules ? [{
      name     = "AWSManagedRulesCommonRuleSet"
      priority = var.owasp_rules_priority
      vendor   = "AWS"
    }] : [],
    var.enable_ip_reputation ? [{
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = var.ip_reputation_priority
      vendor   = "AWS"
    }] : [],
    var.enable_anonymous_ip ? [{
      name     = "AWSManagedRulesAnonymousIpList"
      priority = var.anonymous_ip_priority
      vendor   = "AWS"
    }] : []
  )
}

# ==============================================================================
# WAF WebACL
# ==============================================================================

resource "aws_wafv2_web_acl" "this" {
  name        = var.name
  description = var.description != null ? var.description : "WAF WebACL for ${var.name}"
  scope       = var.scope

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }

    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  # ==============================================================================
  # AWS Managed Rule Groups
  # ==============================================================================

  dynamic "rule" {
    for_each = local.managed_rule_groups
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          vendor_name = rule.value.vendor
          name        = rule.value.name

          # Exclude specific rules if needed (can be extended)
          # dynamic "excluded_rule" {
          #   for_each = lookup(rule.value, "excluded_rules", [])
          #   content {
          #     name = excluded_rule.value
          #   }
          # }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "${local.metric_name}-${rule.value.name}"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ==============================================================================
  # Rate Limiting Rule
  # ==============================================================================

  dynamic "rule" {
    for_each = var.enable_rate_limiting ? [1] : []
    content {
      name     = "${var.name}-rate-limit"
      priority = var.rate_limiting_priority

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "${local.metric_name}-rate-limit"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ==============================================================================
  # Geo Blocking Rule
  # ==============================================================================

  dynamic "rule" {
    for_each = var.enable_geo_blocking && length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "${var.name}-geo-block"
      priority = var.geo_blocking_priority

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
        metric_name                = "${local.metric_name}-geo-block"
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  # ==============================================================================
  # Custom Rules
  # ==============================================================================

  dynamic "rule" {
    for_each = var.custom_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [1] : []
          content {}
        }

        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        # Byte match statement
        dynamic "byte_match_statement" {
          for_each = rule.value.statement.byte_match_statement != null ? [rule.value.statement.byte_match_statement] : []
          content {
            positional_constraint = byte_match_statement.value.positional_constraint
            search_string         = byte_match_statement.value.search_string

            field_to_match {
              # Simplified - extend as needed
              dynamic "uri_path" {
                for_each = byte_match_statement.value.field_to_match == "uri_path" ? [1] : []
                content {}
              }

              dynamic "query_string" {
                for_each = byte_match_statement.value.field_to_match == "query_string" ? [1] : []
                content {}
              }
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }

        # Geo match statement
        dynamic "geo_match_statement" {
          for_each = rule.value.statement.geo_match_statement != null ? [rule.value.statement.geo_match_statement] : []
          content {
            country_codes = geo_match_statement.value.country_codes
          }
        }

        # IP set reference statement
        dynamic "ip_set_reference_statement" {
          for_each = rule.value.statement.ip_set_reference_statement != null ? [rule.value.statement.ip_set_reference_statement] : []
          content {
            arn = ip_set_reference_statement.value.arn
          }
        }

        # Rate based statement
        dynamic "rate_based_statement" {
          for_each = rule.value.statement.rate_based_statement != null ? [rule.value.statement.rate_based_statement] : []
          content {
            limit              = rate_based_statement.value.limit
            aggregate_key_type = rate_based_statement.value.aggregate_key_type
          }
        }

        # Size constraint statement
        dynamic "size_constraint_statement" {
          for_each = rule.value.statement.size_constraint_statement != null ? [rule.value.statement.size_constraint_statement] : []
          content {
            comparison_operator = size_constraint_statement.value.comparison_operator
            size                = size_constraint_statement.value.size

            field_to_match {
              dynamic "uri_path" {
                for_each = size_constraint_statement.value.field_to_match == "uri_path" ? [1] : []
                content {}
              }

              dynamic "query_string" {
                for_each = size_constraint_statement.value.field_to_match == "query_string" ? [1] : []
                content {}
              }

              dynamic "body" {
                for_each = size_constraint_statement.value.field_to_match == "body" ? [1] : []
                content {}
              }
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = rule.value.visibility_config.cloudwatch_metrics_enabled
        metric_name                = rule.value.visibility_config.metric_name
        sampled_requests_enabled   = rule.value.visibility_config.sampled_requests_enabled
      }
    }
  }

  # ==============================================================================
  # Visibility Config (WebACL level)
  # ==============================================================================

  visibility_config {
    cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics
    metric_name                = local.metric_name
    sampled_requests_enabled   = var.sampled_requests_enabled
  }

  tags = merge(
    var.common_tags,
    {
      Name        = var.name
      Description = "WAF WebACL ${var.name}"
    }
  )
}

# ==============================================================================
# WAF Logging Configuration
# ==============================================================================

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_logging && var.log_destination_arn != null ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [var.log_destination_arn]

  dynamic "redacted_fields" {
    for_each = var.redacted_fields
    content {
      dynamic "single_header" {
        for_each = redacted_fields.value.type == "single_header" ? [1] : []
        content {
          name = redacted_fields.value.name
        }
      }

      dynamic "uri_path" {
        for_each = redacted_fields.value.type == "uri_path" ? [1] : []
        content {}
      }

      dynamic "query_string" {
        for_each = redacted_fields.value.type == "query_string" ? [1] : []
        content {}
      }
    }
  }
}

# ==============================================================================
# WAF Resource Association
# ==============================================================================

resource "aws_wafv2_web_acl_association" "this" {
  for_each = toset(var.resource_arns)

  resource_arn = each.value
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}
