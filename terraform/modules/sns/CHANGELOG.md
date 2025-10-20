# Changelog

All notable changes to the SNS Topic Terraform module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-20

### Added
- Initial release of SNS Topic module
- Support for Standard and FIFO topics
- Mandatory KMS encryption with customer-managed keys
- Multiple subscription protocol support (SQS, Lambda, HTTP/S, Email, SMS)
- Filter policy support for selective message routing
- CloudWatch alarms for monitoring (messages published, notifications failed)
- Delivery policy configuration for message retry
- IAM topic policy support
- Standardized tagging with required tags pattern
- Automatic .fifo suffix for FIFO topics
- Content-based deduplication for FIFO topics

### Security
- KMS encryption required for all topics
- Customer-managed KMS keys only (no AWS-managed keys)
- IAM policy support for access control

### Documentation
- Comprehensive README with usage examples
- Basic and advanced example configurations
- Best practices and troubleshooting guide

[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/sns-v1.0.0
