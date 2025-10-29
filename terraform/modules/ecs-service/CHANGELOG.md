# Changelog

All notable changes to the ECS Service module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial ECS Service module implementation
- Task Definition configuration with support for:
  - Container image, CPU, and memory configuration
  - Environment variables and secrets management
  - Container health checks
  - CloudWatch Logs integration
- ECS Service configuration with support for:
  - Fargate launch type
  - Network configuration (VPC, subnets, security groups)
  - Load balancer integration (optional)
  - Deployment strategies (circuit breaker, rolling updates)
  - ECS Exec support
- Auto Scaling support with:
  - CPU-based scaling policies
  - Memory-based scaling policies
  - Configurable min/max capacity
- Comprehensive variable validation
- Standard tag support via common-tags module integration
- Examples for basic, advanced, and complete usage scenarios

### Epic & Task
