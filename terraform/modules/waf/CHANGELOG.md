# Changelog

All notable changes to this module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2025-01-23

### Changed

**BREAKING CHANGE**: Refactored to use `common-tags` module pattern

- **Removed**: `var.common_tags` variable
- **Added**: Individual tag variables (required):
  - `environment` (string, required): Environment name (dev, staging, prod)
  - `service_name` (string, required): Service name (kebab-case)
  - `team` (string, required): Team responsible for the resource
  - `owner` (string, required): Email or identifier of the resource owner
  - `cost_center` (string, required): Cost center for billing
- **Added**: Optional tag variables:
  - `project` (string, default: "infrastructure"): Project name
  - `data_class` (string, default: "confidential"): Data classification level (WAF defaults to confidential)
  - `additional_tags` (map(string), default: {}): Additional tags to merge

### Migration Guide

**Before**:
```hcl
module "waf" {
  source = "../../modules/waf"

  name  = "my-waf"
  scope = "REGIONAL"

  common_tags = module.common_tags.tags
}
```

**After**:
```hcl
module "waf" {
  source = "../../modules/waf"

  name  = "my-waf"
  scope = "REGIONAL"

  # Required tags
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  # Optional tags
  project     = "infrastructure"  # default
  data_class  = "confidential"    # default for WAF
}
```

### Benefits

- **Governance Compliance**: Automatic enforcement through common-tags module
- **Consistency**: Standardized tagging across all infrastructure
- **Validation**: Built-in validation for tag values
- **ManagedBy Tag**: Automatically adds `ManagedBy = "Terraform"` tag
- **Security Focus**: WAF defaults to "confidential" data class for security-sensitive resources

## [1.0.0] - 2025-10-18

### Added
- Initial release of WAF module
- AWS WAF WebACL resource with configurable scope (REGIONAL/CLOUDFRONT)
- AWS Managed OWASP Top 10 rule group integration
- IP-based rate limiting with configurable thresholds
- Geographic blocking with country code filtering
- AWS Managed IP Reputation rules
- AWS Managed Anonymous IP rules (VPN/Proxy/Tor blocking)
- Kinesis Firehose logging integration with field redaction
- CloudWatch metrics and monitoring configuration
- Resource association support (ALB, API Gateway, CloudFront)
- Custom rule support with multiple statement types
- Comprehensive input validation
- Complete output values for integration
- Standard tagging support via common-tags module
- Full documentation and usage examples
- Basic and advanced example configurations

### Features
- **Security Rules**:
  - OWASP Top 10 protection (AWS Managed)
  - Rate limiting (100-20M requests per 5-min)
  - Geo blocking (ISO 3166-1 alpha-2 country codes)
  - IP reputation filtering
  - Anonymous IP blocking

- **Logging & Monitoring**:
  - Kinesis Firehose integration
  - CloudWatch metrics per rule
  - Sampled request logging
  - Field redaction for sensitive data

- **Resource Integration**:
  - Automatic WebACL association
  - Multi-resource support
  - ALB, API Gateway, CloudFront compatibility

- **Governance Compliance**:
  - Kebab-case naming validation
  - Required tags via common-tags module
  - Comprehensive variable validation
  - Security best practices enforcement

### Technical Details
- Terraform >= 1.5.0
- AWS Provider >= 5.0
- Dynamic rule configuration with for_each
- Conditional resource creation
- Comprehensive visibility configuration

### Documentation
- Complete README with usage examples
- Basic example: Simple WAF with OWASP rules
- Advanced example: Full-featured WAF with logging
- CloudFront-specific configuration guide
- Custom rules usage examples
- Cost considerations and guidelines
- Monitoring and alarm recommendations
- Security best practices

### Related

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/modules/waf/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/modules/waf/v1.0.0
