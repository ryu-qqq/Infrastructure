# Changelog

All notable changes to the ALB Terraform module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-16

### Added
- Initial release of ALB module
- Application Load Balancer resource with full configuration support
- Multiple Target Group support with customizable health checks
- HTTP Listener support with configurable default actions
- HTTPS Listener support with SSL/TLS certificate integration
- Listener Rules for path-based and host-based routing
- Session stickiness configuration per target group
- Access logs integration with S3
- Comprehensive variable validation rules
- Complete documentation with examples
- Basic example demonstrating HTTP to HTTPS redirect
- Advanced example with multiple target groups and routing rules

### Features
- ✅ ALB with deletion protection option
- ✅ HTTP/2 support (enabled by default)
- ✅ Configurable idle timeout (1-4000 seconds)
- ✅ Internal and internet-facing ALB support
- ✅ IPv4 and dualstack IP address types
- ✅ Multiple target groups with independent configurations
- ✅ Customizable health checks per target group
- ✅ Session stickiness with configurable cookie duration
- ✅ HTTP listeners with redirect, forward, and fixed-response actions
- ✅ HTTPS listeners with ACM certificate integration
- ✅ Modern SSL/TLS policies (TLS 1.3 support)
- ✅ Path-based routing with priority management
- ✅ Host-based routing support
- ✅ Access logs with S3 bucket integration
- ✅ Comprehensive outputs for all resources
- ✅ Standardized tagging support

### Validation
- ALB name format validation (alphanumeric and hyphens, max 32 chars)
- Minimum 2 subnets requirement for high availability
- VPC ID format validation
- Idle timeout range validation (1-4000 seconds)
- IP address type validation (ipv4 or dualstack)
- Health check timeout < interval validation
- Lambda target type protocol validation (HTTP only)

### Documentation
- Complete README with usage examples
- Basic example with step-by-step guide
- Advanced example demonstrating all features
- Comprehensive variable and output documentation
- Troubleshooting guide
- Security and performance considerations
- Cost optimization tips

### Related Tasks

### Breaking Changes
- None (initial release)

### Known Limitations
- Listener rules only support http and https listener keys (no custom keys)
- Access logs require pre-configured S3 bucket with appropriate bucket policy
- Target group deregistration delay applies to all targets in the group

### Future Enhancements
- Support for weighted target groups
- Support for authentication actions (Cognito, OIDC)
- Enhanced CloudWatch metrics and alarms integration
- Blue/Green deployment support
- WAF integration
