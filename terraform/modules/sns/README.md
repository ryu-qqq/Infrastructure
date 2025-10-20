# SNS Topic Terraform Module

AWS SNS(Simple Notification Service) 토픽을 배포하고 관리하기 위한 재사용 가능한 Terraform 모듈입니다. Standard 및 FIFO 토픽을 지원하며, KMS 암호화, 구독 관리, CloudWatch 모니터링을 포함합니다.

## Features

- ✅ Standard 및 FIFO 토픽 지원
- 🔐 KMS 고객 관리형 키를 이용한 at-rest 암호화 (필수)
- 📬 다중 구독 프로토콜 지원 (SQS, Lambda, HTTP/S, Email, SMS)
- 🎯 필터 정책을 통한 선택적 메시지 라우팅
- 📊 CloudWatch 알람 자동 생성 (발행 메시지 수, 실패한 알림)
- 🔄 메시지 재시도를 위한 전달 정책(Delivery Policy) 지원
- ✅ 표준화된 태그 자동 적용
- 🔒 IAM 토픽 정책 지원

## Usage

### Basic Example

```hcl
module "notifications" {
  source = "../../modules/sns"

  name       = "user-notifications"
  kms_key_id = aws_kms_key.sns.arn

  environment = "dev"
  service     = "notification-service"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  project     = "user-engagement"

  subscriptions = [
    {
      protocol = "sqs"
      endpoint = aws_sqs_queue.notifications.arn
    }
  ]

  enable_cloudwatch_alarms = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Inputs

See complete documentation in module source for all variables.

## Outputs

| Name | Description |
|------|-------------|
| `topic_arn` | ARN of the SNS topic |
| `topic_name` | Name of the SNS topic |
| `subscription_arns` | Map of subscription ARNs |

## Examples

- [basic](./examples/basic/) - Standard SNS topic
- [subscription](./examples/subscription/) - Advanced subscriptions

## License

Maintained as part of infrastructure repository.
