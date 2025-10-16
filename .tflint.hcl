# TFLint Configuration
# Documentation: https://github.com/terraform-linters/tflint

config {
  # Enable module inspection
  module = true

  # Force the check to fail even if there are no errors
  force = false

  # Disable rules for specific paths
  disabled_by_default = false
}

# AWS Plugin
plugin "aws" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# ============================================================================
# AWS Best Practices Rules
# ============================================================================

# Terraform Best Practices
rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true

  variable {
    format = "snake_case"
  }

  locals {
    format = "snake_case"
  }

  output {
    format = "snake_case"
  }

  resource {
    format = "snake_case"
  }

  module {
    format = "snake_case"
  }

  data {
    format = "snake_case"
  }
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}

# AWS Specific Rules
rule "aws_resource_missing_tags" {
  enabled = true
  tags = [
    "Environment",
    "Service",
    "Team",
    "Owner",
    "CostCenter",
    "ManagedBy",
    "Project"
  ]
}

rule "aws_s3_bucket_versioning" {
  enabled = true
}

rule "aws_db_instance_invalid_type" {
  enabled = true
}

rule "aws_elasticache_cluster_invalid_type" {
  enabled = true
}

rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_route_not_specified_target" {
  enabled = true
}

rule "aws_route_specified_multiple_targets" {
  enabled = true
}
