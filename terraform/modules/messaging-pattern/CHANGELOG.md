# Changelog

All notable changes to the Messaging Pattern Terraform module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-11-23

### Changed
- **BREAKING**: Migrated to common-tags module pattern for standardized tagging
- **BREAKING**: Removed local.required_tags (now using module.tags.tags)
- **BREAKING**: Added required variable: `data_class` for data classification
- Added optional variable defaults: `project` (default: "infrastructure"), `data_class` (default: "confidential")
- Updated SNS and SQS submodule calls to pass `data_class` variable
- Simplified `additional_tags` handling in submodule calls (Pattern and SubscribedTopic tags only)

### Added
- Integration with common-tags module for standardized governance
- Validation rules for `project` and `data_class` variables
- Support for data classification tagging (confidential, internal, public)

### Migration Guide

#### Before (v1.x)
```hcl
module "notification_fanout" {
  source = "../../modules/messaging-pattern"

  sns_topic_name = "user-notifications"
  kms_key_id     = aws_kms_key.messaging.arn

  environment = "dev"
  service     = "notification-service"
  team        = "platform-team"
  owner       = "fbtkdals2@naver.com"
  cost_center = "engineering"
  project     = "user-engagement"

  # ... sqs_queues config
}
```

#### After (v2.x)
```hcl
module "notification_fanout" {
  source = "../../modules/messaging-pattern"

  sns_topic_name = "user-notifications"
  kms_key_id     = aws_kms_key.messaging.arn

  # Required tags (same as before)
  environment = "dev"
  service     = "notification-service"
  team        = "platform-team"
  owner       = "fbtkdals2@naver.com"
  cost_center = "engineering"

  # Optional tags (now with defaults and validation)
  project    = "user-engagement"
  data_class = "confidential"  # NEW: explicitly specify or use default

  additional_tags = {
    Component = "messaging"
  }

  # ... sqs_queues config
}
```

## [1.0.0] - 2025-10-20

### Added
- Initial release of Messaging Pattern module (Fan-out)
- Automatic SNS-to-SQS fan-out pattern configuration
- Support for multiple SQS queue subscriptions from single SNS topic
- Filter policy support for selective message routing
- Automatic IAM permission configuration (SNS → SQS)
- Mandatory KMS encryption for both SNS and SQS
- Automatic DLQ configuration for all SQS queues
- Support for Standard and FIFO messaging
- CloudWatch alarms for SNS and all SQS queues
- Standardized tagging across all resources
- Pattern-specific resource tagging

### Modules Used
- SNS Topic module (../sns)
- SQS Queue module (../sqs)

### Security
- KMS encryption for all messaging resources
- Automatic IAM policy documents for SNS-to-SQS access
- Source ARN conditions in IAM policies
- Customer-managed KMS keys only

### Documentation
- Comprehensive README with fan-out pattern explanation
- Basic and advanced example configurations
- Use case examples and best practices
- Filter policy design guidelines

[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/messaging-pattern-v1.0.0
