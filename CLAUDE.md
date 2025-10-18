# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Infrastructure as Code (IaC) repository managing AWS infrastructure with Terraform. Features automated governance validation, security scanning, and CI/CD pipelines for infrastructure deployment.

**Primary Technologies**: Terraform, AWS, Docker, GitHub Actions
**Governance**: Required tags, KMS encryption, naming conventions, security scans (tfsec, checkov)

## Essential Commands

### Terraform Operations

```bash
# Initialize and validate
cd terraform/{module-name}
terraform init
terraform fmt
terraform validate
terraform plan

# Apply changes (typically done via CI/CD)
terraform apply
```

### Governance Validation

```bash
# Install validation hooks (run once)
./scripts/setup-hooks.sh

# Run individual validators
./scripts/validators/check-tags.sh          # Required tags validation
./scripts/validators/check-encryption.sh    # KMS encryption validation
./scripts/validators/check-naming.sh        # Naming conventions validation
./scripts/validators/check-tfsec.sh         # Security scan (AWS best practices)
./scripts/validators/check-checkov.sh       # Compliance validation

# Validate single file (used by Claude hooks)
./scripts/validators/validate-terraform-file.sh terraform/path/to/file.tf
```

### Docker Build and Push

```bash
# Build and push to ECR (manual, CI/CD handles this automatically)
./scripts/build-and-push.sh

# With custom options
ATLANTIS_VERSION=v0.30.0 CUSTOM_TAG=prod ./scripts/build-and-push.sh
```

### Testing

```bash
# Atlantis operations
./scripts/atlantis/check-atlantis-health.sh    # Health check
./scripts/atlantis/monitor-atlantis-logs.sh    # Live log monitoring
./scripts/atlantis/restart-atlantis.sh         # Restart service
```

## Architecture Patterns

### 🔴 CRITICAL: Mandatory Governance Rules

**1. Required Tags Pattern**
ALL AWS resources MUST use `merge(local.required_tags)`:

```hcl
resource "aws_ecr_repository" "example" {
  name = "example"

  tags = merge(
    local.required_tags,  # REQUIRED - includes Owner, CostCenter, Environment, etc.
    {
      Name      = "ecr-example"
      Component = "example"
    }
  )
}
```

Required tags: `Owner`, `CostCenter`, `Environment`, `Lifecycle`, `DataClass`, `Service`

**2. KMS Encryption**
ALL encryption MUST use customer-managed KMS keys (no AES256):

```hcl
resource "aws_ecr_repository" "example" {
  encryption_configuration {
    encryption_type = "KMS"
    kms_key        = aws_kms_key.ecr.arn  # Customer-managed key
  }
}
```

**3. Naming Conventions**
- Resources: `kebab-case` (e.g., `ecr-atlantis`, `prod-server-vpc`)
- Variables/Locals: `snake_case` (e.g., `aws_region`, `required_tags`)

**4. No Hardcoded Secrets**
Never hardcode passwords, API keys, or secrets in Terraform code.

### Terraform State Management

**Backend Configuration**:
```hcl
terraform {
  backend "s3" {
    bucket         = "ryuqqq-${var.env}-tfstate"
    key            = "${var.stack}/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
    kms_key_id     = "alias/terraform-state"
  }
}
```

**State Isolation**:
- Environment-based: `dev`, `staging`, `prod`
- Region-based: `ap-northeast-2` (primary), `ap-northeast-1` (DR)
- Domain-based: `network`, `security`, `monitoring`, `application`

**Cross-Stack References**: Use Output → SSM Parameter Store → Input pattern (no direct cross-stack dependencies)

### Reusable Modules Structure

Standard module directory structure:
```
terraform/modules/{module-name}/
├── README.md          # Module documentation
├── main.tf            # Resource definitions
├── variables.tf       # Input variables
├── outputs.tf         # Output values
├── versions.tf        # Provider version constraints
├── CHANGELOG.md       # Version history
└── examples/          # Usage examples
    ├── basic/
    └── advanced/
```

**Active Modules**:
- `common-tags`: Standard resource tagging
- `cloudwatch-log-group`: Log group with encryption
- `ecs-service`: ECS service deployment
- `rds`: RDS instance with Multi-AZ
- `alb`: Application Load Balancer
- `iam-role-policy`: IAM role and policy management
- `security-group`: Security group templates

**Module Usage Pattern**:
```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "api-server"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}

module "app_logs" {
  source = "../../modules/cloudwatch-log-group"

  name              = "/aws/ecs/api-server/application"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
  common_tags       = module.common_tags.tags
}
```

### Security and Compliance

**Multi-Layer Security Validation**:
1. **tfsec**: AWS security best practices (encryption, IAM, network security)
2. **checkov**: Compliance frameworks (CIS AWS, PCI-DSS, HIPAA)
3. **conftest**: OPA policy validation (tags, naming conventions)
4. **Infracost**: Cost impact analysis (10% warning, 30% blocking)

**Severity Levels**:
- CRITICAL: Immediate fix required, blocks deployment
- HIGH: Must fix before PR approval
- MEDIUM: Should fix before PR approval
- LOW: Recommended, non-blocking

**Security Scan Configuration**:
- tfsec: `.tfsec/config.yml`
- checkov: `.checkov.yml`
- OPA policies: `policies/`

### Logging and Monitoring Standards

**CloudWatch Log Naming**:
```
/org/{service}/{env}/{component}
Examples:
/ryuqqq/crawler/prod/api
/ryuqqq/authhub/prod/auth-service
```

**Log Retention**:
- CloudWatch: 7-14 days
- S3 Archive: 90 days (Standard) → 1 year (IA) → 7 years (Glacier)

**Standard Alarms** (all alarms must link to runbooks):
- Application: 5xx > 1%, p95 latency > 1s, error patterns, OOM
- Infrastructure: CPU > 80%, Memory > 85%, Disk > 80%

### Network Architecture

**VPC Design**:
- CIDR: `/16` (e.g., 10.0.0.0/16)
- Public subnets: `/20` (Multi-AZ)
- Private subnets: `/19` (Multi-AZ)
- Data subnets: `/20` (Multi-AZ)

**Mandatory VPC Endpoints** (cost optimization):
- S3 (Gateway)
- DynamoDB (Gateway)
- ECR (Interface)
- Secrets Manager (Interface)

## CI/CD Workflows

### PR Workflow (terraform-plan.yml)
Triggers on PR to `main`:
1. Governance validation (tags, encryption, naming)
2. Security scans (tfsec, checkov)
3. Terraform plan generation
4. Cost analysis (Infracost)
5. PR comment with results

### Merge Workflow (terraform-apply-and-deploy.yml)
Triggers on merge to `main`:
1. Terraform apply
2. Docker image build
3. Push to ECR with tags (git SHA, latest, timestamp)
4. Image vulnerability scan

### Reusable Infrastructure Checks (infra-checks.yml)
Centralized validation workflow including:
- Multiple security scanners (tfsec, checkov)
- Cost validation (Infracost)
- Policy validation (Conftest/OPA)
- Automated PR comments with results

## Operational Patterns

### Session Hooks
Claude Code automatically validates Terraform files after Write/Edit operations using:
- `.claude/hooks.json`: Session hook configuration
- `.claude/INFRASTRUCTURE_RULES.md`: Detailed governance rules

### Change Risk Classification
- **Low Risk**: Tag changes, log levels, scaling parameters
- **Medium Risk**: Security groups, routing tables, environment variables
- **High Risk**: DB schema, network topology, IAM policies (requires rollback plan)

### Deployment Strategy
- Medium+ risk: Blue/Green or Canary deployment required
- High risk: Rollback plan + emergency contacts + validation checklist mandatory

### KMS Key Strategy
Data-class based key separation:
```hcl
resource "aws_kms_key" "log" {
  description             = "KMS key for CloudWatch Logs"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}
```

### Database Operations
**RDS Standard Configuration**:
- Multi-AZ: Required for production
- Backup retention: 7 days minimum
- Performance Insights: Enabled
- Storage encryption: KMS (customer-managed)
- Connection pooling: RDS Proxy recommended

## Important Notes

### Language Preference
- **Korean**: All terminal interactions, process explanations, reports, findings
- **English**: Code, commands, technical identifiers, function names

### Documentation Structure
- `docs/governance/`: Governance standards and policies
- `docs/guides/`: Operational guides and setup instructions
- `docs/modules/`: Module development standards
- `docs/ko/`: Korean documentation (project overview, guides)
- `claudedocs/`: Claude-specific analysis and reports

### Active Infrastructure
- **Atlantis**: ECS-based Terraform automation server with ECR
- **Monitoring**: CloudWatch, Prometheus (AMP), Grafana (AMG)
- **Logging**: CloudWatch Logs with S3 archival pipeline
- **Security**: CloudTrail, KMS, Secrets Manager
- **Network**: VPC, subnets, security groups, VPC endpoints

### Git Workflow
- Feature branches required (never work on `main`)
- PR approval gates with automated validation
- GitHub Actions for automated deployment
- Git hooks for pre-commit/pre-push validation

### Related Jira
- Epic: [IN-1 - Atlantis 서버 ECS 배포](https://ryuqqq.atlassian.net/browse/IN-1)
- Epic: [IN-100 - 재사용 가능한 표준 모듈](https://ryuqqq.atlassian.net/browse/IN-100)
