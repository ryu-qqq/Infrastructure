# Changelog

All notable changes to this module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of CloudFront module
- Support for multiple origins (S3, ALB, Custom)
- Default and ordered cache behaviors
- Custom error responses
- SSL/TLS certificate configuration (ACM or CloudFront default)
- Logging configuration
- WAF integration
- Geographic restrictions
- Lambda@Edge and CloudFront Functions support
- Standard tagging with governance compliance

### Features
- ✅ S3 Origin with Origin Access Identity (OAI)
- ✅ Custom Origin (ALB, EC2, Custom HTTP/HTTPS)
- ✅ Path-based routing with ordered cache behaviors
- ✅ Custom headers for origins
- ✅ Query string and cookie forwarding
- ✅ HTTP/1.1, HTTP/2, HTTP/2+3, HTTP/3 support
- ✅ IPv6 support
- ✅ Price class configuration
- ✅ Geo-restriction (whitelist/blacklist)
- ✅ Custom error pages
- ✅ Access logging to S3
- ✅ AWS WAF Web ACL integration

## [1.0.0] - TBD

Initial stable release.
