# DynamoDB Module

Terraform module for creating DynamoDB tables with encryption, TTL, and auto scaling support.

## Features

- KMS encryption (required for governance compliance)
- Point-in-time recovery
- TTL support
- Global and Local Secondary Indexes
- DynamoDB Streams
- Auto scaling for provisioned capacity mode
- Deletion protection

## Usage

### Basic Table (On-Demand)

```hcl
module "alert_runbooks" {
  source = "../../../modules/dynamodb"

  table_name = "connectly-alert-runbooks"
  hash_key   = "alert_name"
  range_key  = "service"

  attributes = [
    { name = "alert_name", type = "S" },
    { name = "service", type = "S" }
  ]

  kms_key_arn = aws_kms_key.monitoring.arn

  # Required tags
  environment = "prod"
  service     = "monitoring"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}
```

### Table with GSI and TTL

```hcl
module "alert_history" {
  source = "../../../modules/dynamodb"

  table_name = "connectly-alert-history"
  hash_key   = "alert_id"
  range_key  = "timestamp"

  attributes = [
    { name = "alert_id", type = "S" },
    { name = "timestamp", type = "N" },
    { name = "service", type = "S" }
  ]

  global_secondary_indexes = [
    {
      name     = "service-timestamp-index"
      hash_key = "service"
      range_key = "timestamp"
    }
  ]

  ttl_attribute_name = "expiry_time"

  kms_key_arn = aws_kms_key.monitoring.arn

  # Required tags
  environment = "prod"
  service     = "monitoring"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| table_name | Name of the DynamoDB table | string | n/a | yes |
| hash_key | Partition key attribute name | string | n/a | yes |
| range_key | Sort key attribute name | string | null | no |
| attributes | List of attribute definitions | list(object) | n/a | yes |
| kms_key_arn | KMS key ARN for encryption | string | n/a | yes |
| billing_mode | PAY_PER_REQUEST or PROVISIONED | string | PAY_PER_REQUEST | no |
| ttl_attribute_name | TTL attribute name | string | null | no |
| enable_point_in_time_recovery | Enable PITR | bool | true | no |
| stream_enabled | Enable DynamoDB Streams | bool | false | no |
| deletion_protection_enabled | Enable deletion protection | bool | false | no |

## Outputs

| Name | Description |
|------|-------------|
| table_name | Name of the DynamoDB table |
| table_arn | ARN of the DynamoDB table |
| stream_arn | ARN of the DynamoDB Stream |
