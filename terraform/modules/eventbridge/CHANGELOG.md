# Changelog

## [Unreleased]

### Changed
- **BREAKING**: Replaced `common_tags` variable with individual tagging variables
- Module now integrates common-tags module internally for standardized tagging
- Required tagging variables: `environment`, `service_name`, `team`, `owner`, `cost_center`
- Optional tagging variables: `project`, `data_class`, `additional_tags`
- All resources now automatically receive standardized tags from common-tags module

### Migration Guide
Replace:
```hcl
module "eventbridge" {
  common_tags = local.common_tags
}
```

With:
```hcl
module "eventbridge" {
  environment  = "prod"
  service_name = "event-processor"
  team         = "platform-team"
  owner        = "owner@example.com"
  cost_center  = "engineering"
}
```

## [1.0.0] - 2024-11-20

### Added
- Initial release
- Support for ECS, Lambda, SNS, SQS targets
- Schedule expression (cron/rate) support
- Event pattern support
- IAM role for ECS target with least privilege
- Lambda permission for Lambda target
- Comprehensive README with examples
