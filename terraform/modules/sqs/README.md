# SQS Queue Terraform Module

AWS SQS(Simple Queue Service) 큐를 배포하고 관리하기 위한 재사용 가능한 Terraform 모듈입니다. Standard 및 FIFO 큐를 지원하며, 자동 DLQ 구성, KMS 암호화, CloudWatch 모니터링을 포함합니다.

## Features

- ✅ Standard 및 FIFO 큐 지원
- 🔐 KMS 고객 관리형 키를 이용한 at-rest 암호화 (필수)
- 💀 자동 DLQ(Dead Letter Queue) 생성 및 구성
- 🔄 DLQ에서 메인 큐로 복원(Redrive) 지원
- 📊 CloudWatch 알람 자동 생성 (메시지 나이, 큐 깊이, DLQ 메시지)
- ⚙️ 유연한 메시지 구성
- ✅ 표준화된 태그 자동 적용

## Usage

### Basic Example

```hcl
module "task_queue" {
  source = "../../modules/sqs"

  name       = "task-processing-queue"
  kms_key_id = aws_kms_key.sqs.arn

  environment = "dev"
  service     = "task-service"
  team        = "backend-team"
  owner       = "backend@example.com"
  cost_center = "engineering"
  project     = "async-processing"

  visibility_timeout_seconds = 30
  enable_dlq                 = true
  max_receive_count          = 3

  enable_cloudwatch_alarms = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Outputs

| Name | Description |
|------|-------------|
| `queue_arn` | ARN of the SQS queue |
| `queue_url` | URL of the SQS queue |
| `dlq_arn` | ARN of the Dead Letter Queue |

## Examples

- [basic](./examples/basic/) - Standard SQS queue with DLQ
- [fifo](./examples/fifo/) - FIFO queue
- [dlq](./examples/dlq/) - DLQ configuration

## License

Maintained as part of infrastructure repository.
