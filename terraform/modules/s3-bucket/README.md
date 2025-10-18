# S3 Bucket Module

Terraform module for creating standardized S3 buckets with governance compliance.

## Features

- **KMS Encryption**: Customer-managed KMS key encryption support
- **Versioning**: Object versioning for data protection
- **Public Access Block**: Default protection against public exposure
- **Lifecycle Policies**: Configurable lifecycle rules for cost optimization
- **Access Logging**: Optional S3 access logging
- **CORS Configuration**: Support for Cross-Origin Resource Sharing
- **Static Website Hosting**: Optional website hosting configuration
- **Governance Compliance**: Automatic tagging and naming convention validation

## Usage

### Basic Storage Bucket

```hcl
module "data_bucket" {
  source = "../../modules/s3-bucket"

  bucket_name        = "prod-data-storage-bucket"
  versioning_enabled = true

  # Required tags
  environment = "prod"
  service     = "data-storage"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  project     = "infrastructure"

  # Encryption
  kms_key_id = aws_kms_key.bucket.arn

  # Lifecycle policy
  lifecycle_rules = [
    {
      id      = "archive-old-data"
      enabled = true
      prefix  = ""

      transition_to_ia_days      = 30
      transition_to_glacier_days = 90
      expiration_days            = 365

      noncurrent_expiration_days   = 30
      abort_incomplete_upload_days = 7
    }
  ]
}
```

### Static Website Hosting

```hcl
module "website_bucket" {
  source = "../../modules/s3-bucket"

  bucket_name = "prod-static-website-bucket"

  # Required tags
  environment = "prod"
  service     = "static-website"
  team        = "frontend-team"
  owner       = "frontend@example.com"
  cost_center = "engineering"
  project     = "infrastructure"

  # Encryption
  kms_key_id = aws_kms_key.website.arn

  # Static website configuration
  enable_static_website  = true
  website_index_document = "index.html"
  website_error_document = "error.html"

  # Public access for website
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  # CORS configuration
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["https://example.com"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]
}
```

### Logging Bucket

```hcl
module "logs_bucket" {
  source = "../../modules/s3-bucket"

  bucket_name        = "prod-application-logs-bucket"
  versioning_enabled = false

  # Required tags
  environment = "prod"
  service     = "logging"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  project     = "infrastructure"

  # Encryption
  kms_key_id = aws_kms_key.logs.arn

  # Aggressive lifecycle for logs
  lifecycle_rules = [
    {
      id      = "archive-logs"
      enabled = true
      prefix  = ""

      transition_to_ia_days      = 7
      transition_to_glacier_days = 30
      expiration_days            = 90

      abort_incomplete_upload_days = 1
    }
  ]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket_name | Name of the S3 bucket (must follow kebab-case naming convention) | `string` | n/a | yes |
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| service | Service name | `string` | n/a | yes |
| team | Team responsible for this resource | `string` | n/a | yes |
| owner | Owner email or identifier | `string` | n/a | yes |
| cost_center | Cost center for billing | `string` | n/a | yes |
| project | Project name | `string` | n/a | yes |
| kms_key_id | ARN of the KMS key to use for bucket encryption | `string` | `null` | no |
| versioning_enabled | Enable versioning for the S3 bucket | `bool` | `true` | no |
| logging_enabled | Enable access logging for the S3 bucket | `bool` | `false` | no |
| logging_target_bucket | Target bucket for access logs (required if logging_enabled is true) | `string` | `null` | no |
| logging_target_prefix | Prefix for access log objects | `string` | `"logs/"` | no |
| lifecycle_rules | List of lifecycle rules for the S3 bucket | `list(object)` | `[]` | no |
| cors_rules | List of CORS rules for the S3 bucket | `list(object)` | `[]` | no |
| block_public_acls | Block public ACLs on the bucket | `bool` | `true` | no |
| block_public_policy | Block public bucket policies | `bool` | `true` | no |
| ignore_public_acls | Ignore public ACLs on the bucket | `bool` | `true` | no |
| restrict_public_buckets | Restrict public bucket policies | `bool` | `true` | no |
| enable_static_website | Enable static website hosting | `bool` | `false` | no |
| website_index_document | Index document for static website | `string` | `"index.html"` | no |
| website_error_document | Error document for static website | `string` | `"error.html"` | no |
| force_destroy | Allow deletion of non-empty bucket | `bool` | `false` | no |
| additional_tags | Additional tags to apply to the S3 bucket | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | The ID (name) of the bucket |
| bucket_arn | The ARN of the bucket |
| bucket_domain_name | The bucket domain name |
| bucket_regional_domain_name | The bucket region-specific domain name |
| bucket_region | The AWS region this bucket resides in |
| website_endpoint | The website endpoint, if configured |
| website_domain | The domain of the website endpoint, if configured |
| bucket_tags | The tags applied to the bucket |

## Examples

See the `examples/` directory for complete usage examples:
- [basic/](./examples/basic/) - Basic data storage bucket
- [static-hosting/](./examples/static-hosting/) - Static website hosting
- [logging/](./examples/logging/) - Log storage bucket

## Governance Compliance

This module enforces the following governance standards:

1. **Required Tags**: All resources must include Environment, Service, Team, Owner, CostCenter, and Project tags
2. **KMS Encryption**: Supports customer-managed KMS keys (no AES256)
3. **Naming Conventions**: Bucket names must follow kebab-case convention
4. **Public Access**: Defaults to blocking all public access

## Security Best Practices

- Always use customer-managed KMS keys for sensitive data
- Enable versioning for data protection
- Configure lifecycle policies for cost optimization
- Use access logging for audit trails
- Apply principle of least privilege to bucket policies

## License

Apache 2.0 Licensed. See LICENSE for full details.
