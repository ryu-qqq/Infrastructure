# Changelog

All notable changes to the Route53 Record Terraform module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
-

### Changed
-

### Fixed
-

## [2.0.0] - 2025-11-23

### BREAKING CHANGES
- **Added Required Variables**: Must provide `environment`, `service_name`, `team`, `owner`, `cost_center`
- **Note**: Route53 Records do not support tags, but these variables are included for consistency

### Added
- New required variables for consistency: `environment`, `service_name`, `team`, `owner`, `cost_center`
- New optional variables: `project`, `data_class`, `additional_tags`
- Variables reserved for potential future CloudWatch alarm integration

### Changed
- Variable organization: Added tagging variables section
- Documentation: Added note about Route53 Records not supporting tags

### Migration Guide
**Before (v1.x)**:
```hcl
module "route53_record" {
  source = "../../modules/route53-record"

  zone_id = "Z1234567890ABC"
  name    = "api.example.com"
  type    = "A"
  records = ["1.2.3.4"]
}
```

**After (v2.x)**:
```hcl
module "route53_record" {
  source = "../../modules/route53-record"

  zone_id = "Z1234567890ABC"
  name    = "api.example.com"
  type    = "A"
  records = ["1.2.3.4"]

  # New required variables (for consistency, not used for Route53 Record tags)
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

## [1.0.0] - 2024-11-13

### Added
- Initial release of Route53 Record module
- Support for standard DNS record types (A, AAAA, CNAME, MX, TXT, NS, SRV, PTR, SPF, CAA)
- Alias record support for AWS resources (ALB, CloudFront, etc.)
- Weighted routing policy support
- Geolocation routing policy support
- Failover routing policy support
- Health check association
- Allow overwrite option for existing records
- Comprehensive variable validation
- Basic and advanced examples

### Features
- ✅ Standard DNS records with TTL configuration
- ✅ AWS Alias records for AWS resource integration
- ✅ Advanced routing policies (weighted, geolocation, failover)
- ✅ Health check integration
- ✅ Record type validation
- ✅ TTL range validation (60-86400 seconds)

### Validation
- Record type must be valid DNS type
- TTL validation for non-alias records
- Mutual exclusivity between alias and standard records
- Failover type validation (PRIMARY/SECONDARY)

### Outputs
- Record ID
- Record name (FQDN)
