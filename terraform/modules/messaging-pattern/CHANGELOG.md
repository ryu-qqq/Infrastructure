# Changelog

All notable changes to the Messaging Pattern Terraform module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
