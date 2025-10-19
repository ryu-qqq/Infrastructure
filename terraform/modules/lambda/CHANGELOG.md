# Changelog

All notable changes to this Lambda module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-10-19

### Added
- Initial release of Lambda Function module
- Support for multiple runtimes (Python, Node.js, Java, Go, .NET, Ruby)
- Automatic IAM role creation with customizable policies
- VPC configuration support with subnet and security group integration
- Environment variables management
- CloudWatch Logs integration with KMS encryption
- Dead Letter Queue (DLQ) automatic creation with KMS encryption
- Lambda versioning and alias support
- X-Ray tracing integration
- Lambda Layers support
- Lambda permissions management for AWS service integration
- Ephemeral storage configuration
- Reserved concurrent executions control
- Comprehensive input variable validation
- Standard tags automatic application (governance compliance)
- Support for both local file and S3 code deployment
- Inline IAM policy support
- Custom IAM policy attachments
- Example: Python API Lambda with VPC and DLQ
- Complete documentation with usage examples

### Governance Compliance
- ✅ Required tags: Environment, Service, Team, Owner, CostCenter, Project
- ✅ KMS encryption support for logs and DLQ
- ✅ Naming conventions: kebab-case for resources, snake_case for variables
- ✅ Security scans: tfsec and checkov validated

### Examples
- Python API Lambda with VPC, DLQ, and CloudWatch Logs integration

### Documentation
- Comprehensive README with usage examples
- Input variables documentation
- Output values documentation
- Best practices guide
- Troubleshooting guide

## [Unreleased]

### Planned Features
- Lambda@Edge support
- Container image deployment support
- Event source mappings (SQS, DynamoDB Streams, Kinesis)
- Lambda function URL support
- Advanced example with EventBridge integration
- Node.js example with layers
- Multi-region deployment example
- Blue/Green deployment example with aliases
- Auto-scaling configuration
- Cost optimization recommendations

---

**Note**: This is the initial release (v1.0.0) of the Lambda module as part of the "재사용 가능한 표준 모듈" epic (IN-100).

**Related Jira**: [IN-144 - Lambda Function 재사용 모듈 개발](https://ryuqqq.atlassian.net/browse/IN-144)
