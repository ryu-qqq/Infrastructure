# Changelog

All notable changes to the ACM Terraform module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-11-24

### Changed
- **BREAKING**: Migrated to Modules v1.0.0 pattern (individual tag variables)
- Removed `common-tags` module dependency
- Updated `locals.tf` with `required_tags` definition
- Updated `variables.tf` with individual tag variables and validation rules
- Updated all resource tags from `module.common_tags.tags` to `local.required_tags`
- Added `additional_tags` variable for resource-specific custom tags

### Added
- Individual tag variables with validation rules:
  - `environment` (dev, staging, prod)
  - `service` (kebab-case validation)
  - `owner` (email or kebab-case identifier)
  - `cost_center` (kebab-case validation)
  - `managed_by` (terraform, manual, cloudformation, cdk)
  - `project` (kebab-case validation)
  - `data_class` (confidential, internal, public)
- Lifecycle mapping in `locals.tf` (environment → lifecycle)

### Migration Notes
- No infrastructure changes - tags remain identical
- Modules v1.0.0 pattern simplifies dependency management
- All governance standards maintained

## [1.0.0] - 2025-10-18

### Added
- Initial release of ACM Certificate Management module
- Wildcard certificate support for `*.set-of.com` and `set-of.com`
- Automatic DNS validation through Route53 integration
- CloudWatch alarm for certificate expiration monitoring (30-day threshold)
- Comprehensive outputs for certificate ARN, status, and metadata
- Full governance compliance (required tags, security scans)
- README.md with usage examples and troubleshooting guide

### Security
- ✅ tfsec scan passed with zero issues
- ✅ checkov compliance scan passed (CIS AWS, PCI-DSS, HIPAA, ISO/IEC 27001)
- ✅ Governance validation passed (tags, encryption, naming conventions)

### Features
- **Automatic Renewal**: AWS ACM handles automatic certificate renewal
- **Multi-Service Support**: Certificate can be used with ALB, CloudFront, API Gateway, etc.
- **DNS Validation**: Fully automated through Route53
- **Monitoring**: CloudWatch alarm triggers 30 days before expiration

### Infrastructure
- Terraform version: >= 1.5.0
- AWS Provider version: ~> 5.0
- Region: ap-northeast-2 (or us-east-1 for CloudFront)

### References
- Related PR: #[TBD]
