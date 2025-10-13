# Infrastructure Management

Infrastructure as Code (IaC) repository for managing cloud infrastructure with Terraform and container deployments.

## Project Structure

```
infrastructure/
├── .github/           # GitHub Actions workflows
│   └── workflows/
│       ├── terraform-plan.yml           # Terraform plan on PR
│       └── terraform-apply-and-deploy.yml # Apply & deploy on merge
├── .claude/           # Claude Code session configuration
│   ├── hooks.json              # Session hooks for automatic validation
│   └── INFRASTRUCTURE_RULES.md # Governance rules documentation
├── terraform/          # Terraform configurations
│   └── atlantis/      # Atlantis server infrastructure
│       ├── ecr.tf     # ECR repository for Docker images
│       ├── kms.tf     # KMS key for ECR encryption
│       ├── provider.tf # AWS provider configuration
│       └── variables.tf # Terraform variables (includes governance tags)
├── docker/            # Docker configurations
│   └── Dockerfile     # Atlantis custom image
├── scripts/           # Automation scripts
│   ├── validators/    # Governance validation scripts
│   │   ├── check-tags.sh       # Required tags validator
│   │   ├── check-encryption.sh # KMS encryption validator
│   │   ├── check-naming.sh     # Naming conventions validator
│   │   └── validate-terraform-file.sh # Single file validator for Claude hooks
│   ├── hooks/         # Git hooks templates
│   │   ├── pre-commit  # Pre-commit validation
│   │   └── pre-push    # Pre-push validation
│   ├── build-and-push.sh # ECR build and push script (manual/local)
│   └── setup-hooks.sh    # Git hooks installer
├── docs/              # Documentation
│   ├── github_actions_setup.md    # CI/CD setup guide
│   ├── infrastructure_governance.md
│   ├── infrastructure_notion.md
│   └── infrastructure_pr.md
└── README.md         # This file
```

## Development Setup

### 1. Install Git Hooks (Governance Validation)

First, install Git hooks for automatic governance validation:

```bash
./scripts/setup-hooks.sh
```

This installs:
- **pre-commit hook**: Fast validation before commits (fmt, secrets, basic checks)
- **pre-push hook**: Comprehensive validation before push (tags, encryption, naming)

**What gets validated:**
- ✅ Required tags (Owner, CostCenter, Environment, Lifecycle, DataClass, Service)
- ✅ KMS encryption (no AES256, customer-managed keys only)
- ✅ Naming conventions (kebab-case for resources, snake_case for variables)
- ✅ Terraform formatting and validation
- ✅ Sensitive information detection

**Bypass (emergency only):**
```bash
git commit --no-verify  # Skip pre-commit checks
git push --no-verify    # Skip pre-push checks
```

### 2. Manual Validation

Run validators manually anytime:

```bash
# Check required tags
./scripts/validators/check-tags.sh

# Check KMS encryption
./scripts/validators/check-encryption.sh

# Check naming conventions
./scripts/validators/check-naming.sh

# Run all validations (same as pre-push)
./scripts/validators/check-*.sh
```

### 3. Claude Session Hooks (For AI Development)

**When working with Claude Code on this project**, governance validation runs automatically during development:

**Session Hooks** (`.claude/hooks.json`):
- 🔍 **After Write/Edit**: Validates all `.tf` files against governance rules
- 🎯 **Session Start**: Displays governance reminder
- 💡 **On Terraform work**: Reminds about required tags pattern

**Validation Script** (`scripts/validators/validate-terraform-file.sh`):
- ✅ Required tags pattern (`merge(local.required_tags)`)
- ✅ KMS encryption (no AES256)
- ✅ Naming conventions (kebab-case/snake_case)
- ✅ No hardcoded secrets

**Test validation manually**:
```bash
./scripts/validators/validate-terraform-file.sh terraform/atlantis/ecr.tf
```

This creates **two-layer defense**:
1. **Claude hooks**: Validate immediately after code changes
2. **Git hooks**: Final safety net before commit/push

### 4. Governance Standards

All infrastructure code must follow the governance standards defined in:
- `.claude/INFRASTRUCTURE_RULES.md` - Claude session enforcement rules
- `docs/infrastructure_governance.md` - Required tags, KMS strategy, naming rules
- `docs/TAGGING_STANDARDS.md` - AWS resource tagging standards (NEW)
- `docs/NAMING_CONVENTION.md` - AWS resource naming conventions (NEW)
- `docs/infrastructure_pr.md` - PR workflow and gate checklist

#### Tagging Standards

All AWS resources must include the following required tags:

| Tag | Description | Example |
|-----|-------------|---------|
| `Environment` | Environment name | `dev`, `staging`, `prod` |
| `Service` | Service or application name | `api`, `web`, `kms`, `cloudtrail` |
| `Team` | Responsible team | `platform-team`, `backend-team` |
| `Owner` | Owner email or identifier | `platform-team@company.com` |
| `CostCenter` | Cost center for billing | `infrastructure`, `product-development` |
| `ManagedBy` | Management method | `terraform`, `manual`, `cloudformation` |
| `Project` | Project name | `infrastructure`, `user-analytics` |

**Use common tags module** (Recommended):
```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "api"
  team        = "platform-team"
  owner       = "platform-team@company.com"
  cost_center = "infrastructure"
}

resource "aws_instance" "api" {
  tags = module.common_tags.tags
}
```

For detailed tagging guidelines, see [docs/TAGGING_STANDARDS.md](docs/TAGGING_STANDARDS.md).

#### Naming Conventions

All resource names must follow kebab-case format:

| Resource Type | Pattern | Example |
|---------------|---------|---------|
| VPC | `{env}-{purpose}-vpc` | `prod-server-vpc` |
| Subnet | `{env}-{visibility}-{az}-subnet` | `prod-public-a-subnet` |
| Security Group | `{env}-{service}-{purpose}-sg` | `prod-api-alb-sg` |
| KMS Key Alias | `alias/{service}-{purpose}` | `alias/rds-encryption` |
| S3 Bucket | `{org}-{env}-{service}-{purpose}-{account}` | `myorg-prod-logs-cloudtrail-123456789012` |
| IAM Role | `{service}-{purpose}-role` | `ecs-task-execution-role` |

For complete naming guidelines, see [docs/NAMING_CONVENTION.md](docs/NAMING_CONVENTION.md).

#### OPA Policy Validation

Policies are automatically validated during Terraform workflow:

```bash
# Generate Terraform plan JSON
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

# Validate with OPA
opa eval --data policies/ --input tfplan.json "data.terraform.deny"
```

Policies enforce:
- ✅ Required tags presence and format
- ✅ Kebab-case naming conventions
- ✅ Valid tag values (Environment, ManagedBy)
- ✅ Email format for Owner tag

## CI/CD with GitHub Actions

### Overview

This project uses GitHub Actions for automated Terraform deployment and Docker image management:

- **PR Creation**: Automatic Terraform plan and governance validation
- **PR Merge**: Automatic Terraform apply and Docker image build/push to ECR
- **Image Tags**: Git SHA, latest, timestamp (for traceability)

### Setup

1. **AWS OIDC Configuration**: See [GitHub Actions Setup Guide](docs/github_actions_setup.md)
2. **GitHub Secrets**: Configure `AWS_ROLE_ARN` in repository settings
3. **Workflow Files**:
   - `.github/workflows/terraform-plan.yml` - Plan on PR
   - `.github/workflows/terraform-apply-and-deploy.yml` - Apply and deploy on merge

### Workflows

#### Terraform Plan (PR)
Triggers on PR to `main`:
1. ✅ Run governance validators
2. ✅ Terraform format, init, validate
3. ✅ Generate plan and comment on PR

#### Terraform Apply & Deploy (Merge)
Triggers on push to `main`:
1. ✅ Apply Terraform (create ECR)
2. ✅ Build Docker image
3. ✅ Push to ECR with multiple tags
4. ✅ Trigger image scan

### Image Tagging Strategy

Every deployment creates 3 tags:
- **Git SHA**: `{account}.dkr.ecr.{region}.amazonaws.com/atlantis:a1b2c3d` (immutable, recommended for prod)
- **Latest**: `{account}.dkr.ecr.{region}.amazonaws.com/atlantis:latest` (mutable, for dev/staging)
- **Timestamp**: `{account}.dkr.ecr.{region}.amazonaws.com/atlantis:20250110-143022` (immutable, for rollback)

For detailed setup instructions, see [GitHub Actions Setup Guide](docs/github_actions_setup.md).

## Atlantis ECR Setup

### Prerequisites

- AWS CLI configured with appropriate credentials
- Docker installed and running (for local builds)
- Terraform >= 1.5.0
- AWS account with ECR permissions
- Git hooks installed (see Development Setup above)

**Note**: With GitHub Actions configured, manual build/push is optional. CI/CD handles deployment automatically.

### 1. Create ECR Repository

First, create the ECR repository using Terraform:

```bash
cd terraform/atlantis
terraform init
terraform plan
terraform apply
```

This will create:
- ECR repository named `atlantis`
- KMS key for ECR encryption (data-class based separation)
- ECR repository policy (access control for ECS tasks)
- Lifecycle policy to manage image retention (keep last 10 tagged images)
- Image scanning on push enabled
- KMS encryption with automatic key rotation
- Governance-compliant tags (Owner, CostCenter, Environment, Lifecycle, DataClass, Service)

### 2. Build and Push Docker Image

Use the provided script to build and push the Atlantis image to ECR:

```bash
# Default: uses latest Atlantis version and 'latest' tag
./scripts/build-and-push.sh

# Specify Atlantis version
ATLANTIS_VERSION=v0.28.1 ./scripts/build-and-push.sh

# Specify custom tag (e.g., prod, staging)
CUSTOM_TAG=prod ./scripts/build-and-push.sh

# Specify AWS region (default: ap-northeast-2)
AWS_REGION=us-east-1 ./scripts/build-and-push.sh

# Combine multiple options
ATLANTIS_VERSION=v0.28.1 CUSTOM_TAG=prod ./scripts/build-and-push.sh
```

### Image Tagging Strategy

The build script creates three tags for each image:

1. **Version + Timestamp**: `v0.28.1-20240110-123456`
   - Provides unique, time-based versioning
   - Useful for rollbacks and audit trails

2. **Version + Git Commit**: `v0.28.1-abc123`
   - Links image to specific git commit
   - Enables source code traceability

3. **Custom Tag**: `latest`, `prod`, `staging`, etc.
   - Configurable via `CUSTOM_TAG` environment variable
   - Used for environment-specific deployments

### Image Lifecycle Management

The ECR repository includes lifecycle policies:

- **Tagged Images**: Keeps the last 10 images with version tags (prefix: `v`)
- **Untagged Images**: Removes images after 7 days

### Docker Image Details

The Atlantis image is based on the official Atlantis image with additional tools:

- **Base**: `ghcr.io/runatlantis/atlantis:v0.28.1`
- **Additional Tools**:
  - AWS CLI
  - Git
  - Bash
  - curl
- **Health Check**: Configured on port 4141 (`/healthz`)
- **Security**: Runs as `atlantis` user (non-root)

### ECR Repository Outputs

After applying Terraform, you'll get:

```
atlantis_ecr_repository_url = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis"
atlantis_ecr_repository_arn = "arn:aws:ecr:ap-northeast-2:123456789012:repository/atlantis"
```

## Manual Build and Push (Alternative)

If you prefer manual steps:

```bash
# 1. Login to ECR
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.ap-northeast-2.amazonaws.com

# 2. Build image
cd docker
docker build -t atlantis:v0.28.1 .

# 3. Tag image
docker tag atlantis:v0.28.1 \
  123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:v0.28.1

# 4. Push image
docker push \
  123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:v0.28.1
```

## Environment Variables

### Build Script Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_REGION` | AWS region for ECR | `ap-northeast-2` |
| `AWS_ACCOUNT_ID` | AWS account ID (auto-detected if not set) | Auto-detected |
| `ATLANTIS_VERSION` | Atlantis version to use | `v0.28.1` |
| `CUSTOM_TAG` | Custom tag for the image | `latest` |

### Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `environment` | Environment name (dev, staging, prod) | `prod` |
| `aws_region` | AWS region for resources | `ap-northeast-2` |
| `atlantis_version` | Atlantis version to deploy | `latest` |
| `owner` | Team responsible for the resource | `platform-team` |
| `cost_center` | Cost center for billing | `engineering` |
| `lifecycle` | Resource lifecycle (permanent/temporary) | `permanent` |
| `data_class` | Data classification level | `confidential` |
| `service` | Service name | `atlantis` |

## Next Steps

After setting up ECR and pushing the image:

1. **ECS Configuration**: Create ECS cluster and task definition
2. **Load Balancer**: Set up ALB for HTTPS access
3. **SSL Certificate**: Request ACM certificate for domain
4. **Secrets Management**: Configure environment variables and secrets
5. **GitHub Integration**: Set up webhook for Atlantis

## Troubleshooting

### ECR Login Issues

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check ECR permissions
aws ecr describe-repositories --region ap-northeast-2
```

### Docker Build Issues

```bash
# Clear Docker cache
docker system prune -a

# Rebuild without cache
docker build --no-cache -t atlantis:v0.28.1 .
```

### Terraform Issues

```bash
# Refresh state
terraform refresh

# Re-initialize
terraform init -upgrade
```

## Security Considerations

- **Image Scanning**: Enabled on push to detect vulnerabilities
- **KMS Encryption**: Images encrypted at rest with customer-managed KMS key
- **Key Rotation**: Automatic key rotation enabled for KMS key
- **Repository Policy**: Explicit access control for ECS tasks and account principals
- **Non-root User**: Container runs as `atlantis` user
- **Lifecycle Policies**: Automatic cleanup of old images
- **Governance Tags**: All resources tagged according to organizational standards

## Governance Compliance

This infrastructure follows the organization's governance standards:

- **Required Tags**: All resources include Owner, CostCenter, Environment, Lifecycle, DataClass, Service tags
- **KMS Strategy**: Data-class based key separation (ECR uses dedicated KMS key)
- **Access Control**: Least-privilege IAM policies via repository policy
- **Encryption**: Customer-managed KMS keys instead of AWS-managed keys
- **Audit Trail**: All changes tracked through Git and Terraform state

## References

- [Atlantis Documentation](https://www.runatlantis.io/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Related Jira Issues

- **Epic**: [IN-1 - Phase 1: Atlantis 서버 ECS 배포](https://ryuqqq.atlassian.net/browse/IN-1)
- **Task**: [IN-10 - ECR 저장소 생성 및 Docker 이미지 푸시](https://ryuqqq.atlassian.net/browse/IN-10)
# Trigger workflow
