# KMS Module

Common Platform KMS Keys for infrastructure encryption.

## Overview

This module creates and manages 4 KMS keys for different encryption purposes following data-class based key separation principles.

## Keys Created

| Key | Alias | DataClass | Purpose |
|-----|-------|-----------|---------|
| terraform_state | alias/terraform-state | confidential | Terraform State S3 encryption |
| rds | alias/rds-encryption | highly-confidential | RDS instance encryption |
| ecs_secrets | alias/ecs-secrets | confidential | ECS task secrets encryption |
| secrets_manager | alias/secrets-manager | highly-confidential | Secrets Manager encryption |

## Features

- ✅ Automatic key rotation enabled
- ✅ 30-day deletion window
- ✅ Least-privilege key policies
- ✅ Service-specific access control
- ✅ Governance-compliant tagging

## Usage

### Deploy KMS Keys

```bash
cd terraform/kms
terraform init
terraform plan
terraform apply
```

### Reference Keys from Other Modules

```hcl
data "terraform_remote_state" "kms" {
  backend = "s3"
  config = {
    bucket = "prod-connectly"
    key    = "kms/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Use in backend configuration
terraform {
  backend "s3" {
    kms_key_id = "alias/terraform-state"
  }
}

# Use in RDS
resource "aws_db_instance" "example" {
  storage_encrypted = true
  kms_key_id        = data.terraform_remote_state.kms.outputs.rds_key_arn
}
```

## Outputs

All keys provide:
- `*_key_id`: KMS key ID
- `*_key_arn`: KMS key ARN
- `*_key_alias`: KMS key alias
- `kms_keys_summary`: Complete summary of all keys

## Variables

| Name | Description | Default |
|------|-------------|---------|
| environment | Environment name | `prod` |
| aws_region | AWS region | `ap-northeast-2` |
| owner | Resource owner | `platform-team` |
| cost_center | Cost center | `infrastructure` |
| resource_lifecycle | Lifecycle | `permanent` |
| service | Service name | `common-platform` |
| key_deletion_window_in_days | Deletion window | `30` |
| enable_key_rotation | Enable rotation | `true` |

## Security

### Key Policies

Each key has service-specific policies following least-privilege principles:

- **Terraform State**: S3, GitHub Actions
- **RDS**: RDS service, GitHub Actions
- **ECS Secrets**: ECS Tasks, Secrets Manager, GitHub Actions
- **Secrets Manager**: Secrets Manager, Application roles, GitHub Actions

### Monitoring

All key operations are logged to CloudTrail for audit purposes.

## Cost

- **Key Cost**: $1/month per key = $4/month total
- **API Requests**: First 10,000 requests/month free, $0.03/10,000 thereafter

## Documentation

See [KMS Strategy Guide](../../claudedocs/kms-strategy.md) for detailed usage guide.

## Related Issues

- **Epic**: [IN-98 - EPIC 2: 공통 플랫폼 인프라](https://ryuqqq.atlassian.net/browse/IN-98)
- **Task**: [IN-111 - TASK 2-3: KMS 키 전략 수립](https://ryuqqq.atlassian.net/browse/IN-111)
