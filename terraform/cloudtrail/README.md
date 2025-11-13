# CloudTrail Module

Central CloudTrail logging infrastructure with comprehensive security monitoring and log analysis capabilities.

## Overview

This module creates a centralized CloudTrail configuration for tracking all AWS API activity across the account with:
- Multi-region trail with log file validation
- Encrypted S3 storage with lifecycle policies
- CloudWatch Logs integration for real-time monitoring
- Athena-based log analysis
- Automated security event alerts

## Features

- ✅ Multi-region CloudTrail trail
- ✅ KMS encryption for logs (data-at-rest)
- ✅ S3 lifecycle policies (Glacier transition after 30 days)
- ✅ CloudWatch Logs integration
- ✅ Athena query environment with pre-built queries
- ✅ Security event monitoring via EventBridge
- ✅ SNS alerts for critical security events
- ✅ Log file validation for integrity
- ✅ Governance-compliant tagging

## Architecture

```
┌─────────────────┐
│   AWS Services  │
│  (IAM, EC2, S3) │
└────────┬────────┘
         │ API Calls
         ▼
┌─────────────────┐         ┌──────────────┐
│   CloudTrail    │────────▶│  S3 Bucket   │
│   (Multi-Region)│         │  (KMS Enc)   │
└────────┬────────┘         └──────┬───────┘
         │                         │
         │                         │ Lifecycle
         ▼                         ▼
┌─────────────────┐         ┌──────────────┐
│ CloudWatch Logs │         │   Glacier    │
│  (7 days)       │         │  (30+ days)  │
└────────┬────────┘         └──────────────┘
         │
         ├──────────────┐
         │              │
         ▼              ▼
┌─────────────────┐ ┌──────────────┐
│  EventBridge    │ │    Athena    │
│  (Sec Alerts)   │ │  (Analysis)  │
└────────┬────────┘ └──────────────┘
         │
         ▼
┌─────────────────┐
│   SNS Topic     │
│  (Email Alert)  │
└─────────────────┘
```

## Resources Created

### Core Resources
- **CloudTrail Trail**: Multi-region trail with comprehensive event logging
- **S3 Bucket**: Encrypted storage for CloudTrail logs
- **KMS Key**: Customer-managed key for encryption
- **CloudWatch Logs Group**: Real-time log delivery (7-day retention)

### Monitoring & Analysis
- **Athena Workgroup**: Query environment for log analysis
- **Glue Database & Table**: Schema for CloudTrail log structure
- **Named Queries**: Pre-built queries for common security scenarios
- **EventBridge Rules**: Security event detection (5 rules)
- **SNS Topic**: Alert notifications

### Security Events Monitored
1. **Root Account Usage**: Any activity from root account
2. **Unauthorized API Calls**: AccessDenied/UnauthorizedOperation errors
3. **IAM Policy Changes**: Policy creation, modification, attachment
4. **Console Login Failures**: Failed authentication attempts
5. **Security Group Changes**: Network security modifications

## Usage

### Deploy CloudTrail Infrastructure

```bash
cd terraform/cloudtrail

# Configure Terraform backend (required - backend removed from module)
# Create backend.tf with your S3 backend configuration:
cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "cloudtrail/terraform.tfstate"
    region         = "your-region"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"
    dynamodb_table = "terraform-lock"
  }
}
EOF

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var="aws_account_id=<YOUR_AWS_ACCOUNT_ID>"

# Apply the configuration
terraform apply -var="aws_account_id=<YOUR_AWS_ACCOUNT_ID>"
```

### Configure Variables

Create `terraform.tfvars`:

```hcl
aws_account_id = "<YOUR_AWS_ACCOUNT_ID>"
aws_region     = "ap-northeast-2"
environment    = "prod"

# CloudTrail Configuration
cloudtrail_name                 = "central-cloudtrail"
enable_log_file_validation      = true
is_multi_region_trail           = true
include_global_service_events   = true

# Storage Configuration
s3_bucket_name      = "cloudtrail-logs"
s3_key_prefix       = "cloudtrail"
log_retention_days  = 90

# Monitoring Configuration
enable_cloudwatch_logs  = true
enable_athena           = true
enable_security_alerts  = true
alert_email             = "your-team@example.com"  # Optional

# Tags
owner              = "platform-team"
cost_center        = "infrastructure"
resource_lifecycle = "permanent"
service            = "common-platform"
```

### Query CloudTrail Logs with Athena

1. **Navigate to Athena Console**
2. **Select Workgroup**: `cloudtrail-analysis`
3. **Select Database**: `cloudtrail_logs`
4. **Run Pre-built Queries**:
   - `unauthorized-api-calls`: Find access denied events
   - `root-account-usage`: Detect root account activity
   - `console-login-failures`: Failed login attempts
   - `iam-policy-changes`: IAM policy modifications

**Example Custom Query**:
```sql
SELECT
  useridentity.arn,
  eventtime,
  eventname,
  sourceipaddress
FROM cloudtrail_logs
WHERE eventname = 'RunInstances'
  AND date >= date_format(current_date - interval '1' day, '%Y/%m/%d')
ORDER BY eventtime DESC
LIMIT 100;
```

### Security Alert Subscription

If you provided an `alert_email`, confirm the SNS subscription:

1. Check your email for "AWS Notification - Subscription Confirmation"
2. Click the confirmation link
3. You'll receive security alerts automatically

## Pre-built Athena Queries

| Query Name | Description | Lookback Period |
|------------|-------------|-----------------|
| `unauthorized-api-calls` | AccessDenied/UnauthorizedOperation errors | 7 days |
| `root-account-usage` | Any root account activity | 30 days |
| `console-login-failures` | Failed console login attempts | 7 days |
| `iam-policy-changes` | IAM policy modifications | 30 days |

## Cost Estimation

### Monthly Costs
- **CloudTrail**: $2.00 (first trail free, data events charged)
- **S3 Storage**: ~$5-10 (depends on log volume)
- **KMS**: $1.00/month + $0.03/10K requests
- **CloudWatch Logs**: ~$2-5 (7-day retention)
- **Athena**: Pay-per-query ($5/TB scanned)
- **SNS**: First 1,000 emails free, $2/100K thereafter

**Estimated Total**: $10-20/month

### Cost Optimization Tips
1. Use S3 lifecycle policies (auto-enabled)
2. Limit Athena scans with partition pruning
3. Use CloudWatch Logs for recent data only
4. Configure data event logging selectively

## Security Best Practices

✅ **Implemented**:
- KMS encryption for logs at rest
- SSL/TLS enforcement for S3 access
- Log file validation enabled
- Versioning enabled on S3 bucket
- Public access blocked
- Multi-region coverage

⚠️ **Recommendations**:
- Review security alerts daily
- Rotate alert email list quarterly
- Test Athena queries monthly
- Validate backup/archive process

## Troubleshooting

### CloudTrail Not Logging

```bash
# Check trail status
aws cloudtrail get-trail-status --name central-cloudtrail

# Verify S3 bucket policy
aws s3api get-bucket-policy --bucket cloudtrail-logs-<ACCOUNT_ID>

# Check KMS key policy
aws kms get-key-policy --key-id alias/cloudtrail-logs --policy-name default
```

### Athena Query Failures

```sql
-- Test table schema
SELECT * FROM cloudtrail_logs LIMIT 1;

-- Verify partitions
SHOW PARTITIONS cloudtrail_logs;

-- Refresh partitions
MSCK REPAIR TABLE cloudtrail_logs;
```

### No Security Alerts

```bash
# Check SNS subscription status
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:<AWS_REGION>:<ACCOUNT_ID>:cloudtrail-security-alerts

# Test SNS topic
aws sns publish \
  --topic-arn arn:aws:sns:<AWS_REGION>:<ACCOUNT_ID>:cloudtrail-security-alerts \
  --message "Test alert"

# Check EventBridge rule status
aws events list-rules --name-prefix cloudtrail-
```

## Compliance

This CloudTrail configuration supports:
- **CIS AWS Foundations Benchmark**: Sections 3.1-3.11
- **AWS Well-Architected Framework**: Security Pillar
- **GDPR**: Audit trail requirements
- **SOC 2**: Logging and monitoring controls

## Outputs

| Output | Description |
|--------|-------------|
| `cloudtrail_arn` | ARN of the CloudTrail trail |
| `cloudtrail_bucket_arn` | ARN of the S3 bucket |
| `cloudtrail_kms_key_arn` | ARN of the KMS encryption key |
| `athena_workgroup_name` | Name of Athena workgroup |
| `security_alerts_topic_arn` | ARN of SNS alert topic |
| `cloudtrail_summary` | Complete configuration summary |

## Integration

### Reference from Other Modules

```hcl
data "terraform_remote_state" "cloudtrail" {
  backend = "s3"
  config = {
    bucket = "prod-tfstate"
    key    = "cloudtrail/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Use CloudTrail KMS key for other services
resource "aws_s3_bucket" "example" {
  # ... bucket config ...
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = data.terraform_remote_state.cloudtrail.outputs.cloudtrail_kms_key_arn
    }
  }
}
```

## Documentation

See [CloudTrail Operations Guide](../../claudedocs/cloudtrail-operations-guide.md) for:
- Daily operational procedures
- Incident response playbooks
- Log analysis examples
- Troubleshooting procedures

## Related Issues


## References

- [AWS CloudTrail Documentation](https://docs.aws.amazon.com/cloudtrail/)
- [CloudTrail Best Practices](https://docs.aws.amazon.com/cloudtrail/latest/userguide/best-practices-security.html)
- [Analyzing CloudTrail Logs with Athena](https://docs.aws.amazon.com/athena/latest/ug/cloudtrail-logs.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
