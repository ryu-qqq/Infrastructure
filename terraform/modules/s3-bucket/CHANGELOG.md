# Changelog

All notable changes to this module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-10-18

### Added
- Initial release of S3 Bucket module
- KMS encryption support with customer-managed keys
- Object versioning configuration
- Public access block settings (enabled by default)
- Access logging configuration
- Lifecycle policy support for cost optimization (Standard → IA → Glacier transitions)
- CORS configuration for cross-origin requests
- Static website hosting support
- Governance-compliant tagging with required tags validation
- Bucket naming convention validation (kebab-case)
- Example configurations:
  - Basic data storage bucket
  - Static website hosting bucket
  - Application logs storage bucket
- Comprehensive documentation in README.md

### Features
- **Encryption**: Customer-managed KMS key encryption by default
- **Versioning**: Configurable object versioning for data protection
- **Lifecycle Management**: Flexible lifecycle rules for cost optimization
- **Security**: Public access blocked by default, configurable for specific use cases
- **Compliance**: Automatic governance tag enforcement
- **Flexibility**: Support for multiple use cases (storage, hosting, logging)

### Security
- Public access blocked by default for all buckets
- KMS encryption support for data at rest
- Validation for required governance tags
- Bucket naming convention enforcement

[1.0.0]: https://github.com/ryu-qqq/Infrastructure/releases/tag/s3-bucket-module-v1.0.0
