# Infrastructure Management

Infrastructure as Code (IaC) repository for managing cloud infrastructure with Terraform and container deployments.

## Project Structure

```
infrastructure/
├── terraform/          # Terraform configurations
│   └── atlantis/      # Atlantis server infrastructure
│       ├── ecr.tf     # ECR repository for Docker images
│       ├── kms.tf     # KMS key for ECR encryption
│       ├── provider.tf # AWS provider configuration
│       └── variables.tf # Terraform variables (includes governance tags)
├── docker/            # Docker configurations
│   └── Dockerfile     # Atlantis custom image
├── scripts/           # Automation scripts
│   └── build-and-push.sh # ECR build and push script
├── docs/              # Documentation
│   ├── infrastructure_governance.md
│   ├── infrastructure_notion.md
│   └── infrastructure_pr.md
└── README.md         # This file
```

## Atlantis ECR Setup

### Prerequisites

- AWS CLI configured with appropriate credentials
- Docker installed and running
- Terraform >= 1.5.0
- AWS account with ECR permissions

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
