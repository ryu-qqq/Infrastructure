---FILE: terraform/environments/prod/test-new-service/main.tf---
```hcl
locals {
  required_tags = {
    Owner       = "owner"
    CostCenter  = "cost_center"
    Environment = "prod"
    Lifecycle   = "lifecycle"
    DataClass   = "data_class"
    Service     = "test-new-service"
  }
}

resource "aws_cloudwatch_log_group" "log_group" {
  name              = "/prod/test-new-service/logs"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.log_key.arn

  tags = merge(local.required_tags, {
    Name = "prod-test-new-service-logs"
  })
}

resource "aws_kms_key" "log_key" {
  description             = "KMS key for CloudWatch logs encryption"
  deletion_window_in_days = 10

  tags = merge(local.required_tags, {
    Name = "prod-test-new-service-log-key"
  })
}
```
---END FILE---

---FILE: terraform/environments/prod/test-new-service/variables.tf---
```hcl
variable "owner" {
  description = "Owner of the resources"
  type        = string
}

variable "cost_center" {
  description = "Cost center for the resources"
  type        = string
}

variable "environment" {
  description = "Environment for the resources"
  default     = "prod"
}

variable "lifecycle" {
  description = "Lifecycle phase of the resources"
  type        = string
}

variable "data_class" {
  description = "Data classification of the resources"
  type        = string
}

variable "service" {
  description = "Service name"
  default     = "test-new-service"
}
```
---END FILE---

---FILE: terraform/environments/prod/test-new-service/outputs.tf---
```hcl
output "log_group_name" {
  description = "The name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.log_group.name
}

output "log_key_arn" {
  description = "The ARN of the KMS key used for logs encryption"
  value       = aws_kms_key.log_key.arn
}
```
---END FILE---