# Changelog

All notable changes to the SQS Queue Terraform module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres on [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-20

### Added
- Initial release of SQS Queue module
- Support for Standard and FIFO queues
- Automatic Dead Letter Queue (DLQ) creation and configuration
- Mandatory KMS encryption with customer-managed keys
- Redrive policy for DLQ to main queue
- CloudWatch alarms for monitoring (message age, queue depth, DLQ messages)
- Flexible message configuration (visibility timeout, retention, size)
- FIFO-specific configuration (deduplication scope, throughput limit)
- IAM queue policy support
- Standardized tagging with required tags pattern
- Automatic .fifo suffix for FIFO queues
- Content-based deduplication for FIFO queues
- Long polling support

### Security
- KMS encryption required for all queues
- Customer-managed KMS keys only (no AWS-managed keys)
- IAM policy support for access control
- KMS data key reuse period configuration

### Documentation
- Comprehensive README with usage examples
- Basic, FIFO, and DLQ example configurations
- Best practices and troubleshooting guide

[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/sqs-v1.0.0
