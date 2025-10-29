# Messaging Pattern Terraform Module

AWS SNS와 SQS를 결합한 Fan-out 메시징 패턴을 구현하는 Terraform 모듈입니다. 하나의 SNS 토픽에서 여러 SQS 큐로 메시지를 분산하며, 필터 정책을 통한 선택적 라우팅과 자동 IAM 권한 설정을 제공합니다.

## Features

- ✅ Fan-out 패턴 자동 구성 (1 SNS → 다수 SQS)
- 🎯 필터 정책을 통한 선택적 메시지 라우팅
- 🔐 KMS 암호화 (SNS 및 SQS 모두)
- 🔒 자동 IAM 권한 설정 (SNS → SQS)
- 💀 모든 SQS 큐에 자동 DLQ 구성
- 📊 통합 CloudWatch 모니터링
- 🔄 Standard 및 FIFO 모드 지원

## Usage

### Basic Example

```hcl
module "notification_fanout" {
  source = "../../modules/messaging-pattern"

  sns_topic_name = "user-notifications"
  kms_key_id     = aws_kms_key.messaging.arn

  environment = "dev"
  service     = "notification-service"
  team        = "platform-team"
  owner       = "fbtkdals2@naver.com"
  cost_center = "engineering"
  project     = "user-engagement"

  sqs_queues = [
    { name = "email-notifications" },
    { name = "sms-notifications" },
    { name = "push-notifications" }
  ]

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
| `sns_topic_arn` | ARN of the SNS topic |
| `sqs_queue_arns` | Map of queue names to ARNs |
| `subscription_arns` | Map of subscription ARNs |

## Examples

- [fanout](./examples/fanout/) - Fan-out pattern with multiple queues

## License

Maintained as part of infrastructure repository.
