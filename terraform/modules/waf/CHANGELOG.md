# Changelog

All notable changes to this module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- Epic: [IN-98 - 공통 플랫폼 인프라](https://ryuqqq.atlassian.net/browse/IN-98)
- Task: [IN-141 - WAF 공통 규칙 구축](https://ryuqqq.atlassian.net/browse/IN-141)

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/modules/waf/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/modules/waf/v1.0.0
