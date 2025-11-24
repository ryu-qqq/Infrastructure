# Changelog

All notable changes to the CloudWatch Log Group module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-11-23

### Breaking Changes
- **REQUIRED**: Replaced individual tag variables with common-tags module integration
- **REQUIRED**: Now requires `environment`, `service_name`, `team`, `owner`, `cost_center` variables
- **REMOVED**: `local.required_tags` replaced with `module.tags.tags`
- Variable name change: `service` → `service_name` for consistency

### Added
- Common-tags module integration for standardized tagging governance
- New required variables: `environment`, `service_name`, `team`, `owner`, `cost_center`
- New optional variables: `project` (default: "infrastructure"), `data_class` (default: "confidential")
- `Component` tag automatically applied (value: "log-group")
- Comprehensive tagging validation rules for all tagging variables

### Changed
- All resources now use `module.tags.tags` instead of `local.required_tags`
- Variable `service` renamed to `service_name` for consistency with other modules
- Default `data_class` set to "confidential" for log data protection
- Enhanced tag documentation in README

### Migration Guide

**Before (v1.x):**
```hcl
module "application_logs" {
  source = "../../modules/cloudwatch-log-group"

  name               = "/aws/ecs/api-server/application"
  retention_in_days  = 14
  kms_key_id         = aws_kms_key.cloudwatch_logs.arn

  # Individual tag variables
  environment = "prod"
  service     = "api-server"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  project     = "infrastructure"
}
```

**After (v2.0):**
```hcl
module "application_logs" {
  source = "../../modules/cloudwatch-log-group"

  name               = "/aws/ecs/api-server/application"
  retention_in_days  = 14
  kms_key_id         = aws_kms_key.cloudwatch_logs.arn

  # Required tagging variables
  environment  = "prod"
  service_name = "api-server"  # Changed from 'service'
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  # Optional (defaults shown)
  project    = "infrastructure"
  data_class = "confidential"
}
```

**Key Changes:**
1. Variable `service` renamed to `service_name`
2. All tagging variables now have validation rules
3. Common-tags module provides standardized tag structure
4. New `Component` tag automatically added

## [1.0.0] - 2025-11-10

### Added
- Initial release of CloudWatch Log Group module
- KMS encryption support for log data protection
- Configurable retention policies (0-3653 days)
- Standard tagging with required governance tags
- Sentry integration preparation (subscription filter)
- Langfuse integration preparation (subscription filter)
- Error rate monitoring metric filter
- Naming convention validation
- Log type classification (application, errors, llm, access, audit, slowquery, general)

### Features
- ✅ CloudWatch Log Group creation with encryption
- ✅ KMS encryption support (customer-managed keys)
- ✅ Flexible retention policies
- ✅ Subscription filters for external integrations
- ✅ Metric filters for error rate monitoring
- ✅ Comprehensive tagging support
- ✅ Naming convention enforcement
- ✅ S3 export capability (optional)

### Validation
- Log group name pattern validation
- Retention period value validation
- Log type validation
- Sync status validation (pending, enabled, disabled)

### Documentation
- Complete README with usage examples
- Basic, error, and LLM log examples
- Comprehensive variable documentation
- Tagging standards documentation
- Future enhancement roadmap
