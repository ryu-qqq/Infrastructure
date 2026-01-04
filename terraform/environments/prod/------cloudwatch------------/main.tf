---FILE: terraform/environments/prod/test-service/main.tf---
```hcl
provider "aws" {
  region = var.region
}

resource "aws_kms_key" "log_group_key" {
  description             = "KMS key for CloudWatch log group encryption"
  deletion_window_in_days = 10

  tags = merge(local.required_tags, {
    Name = "/aws/ecs/test-service/application-key"
  })
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/ecs/test-service/application"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.log_group_key.arn

  tags = merge(local.required_tags, {
    Name = "/aws/ecs/test-service/application"
  })
}

locals {
  required_tags = {
    Owner       = "ryu-qqq"
    CostCenter  = "123456" # 예시 값, 필요한 경우 업데이트
    Environment = "prod"
    Lifecycle   = "test"
    DataClass   = "confidential"
    Service     = "test-service"
  }
}
```
---END FILE---

---FILE: terraform/environments/prod/test-service/variables.tf---
```hcl
variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
```
---END FILE---

---FILE: terraform/environments/prod/test-service/outputs.tf---
```hcl
output "log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.application.name
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = aws_kms_key.log_group_key.arn
}
```
---END FILE---