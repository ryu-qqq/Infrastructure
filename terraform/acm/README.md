# ACM (AWS Certificate Manager) Terraform Module

AWS Certificate Manager를 사용하여 SSL/TLS 인증서를 중앙에서 관리하는 Terraform 모듈입니다.

## 개요

이 모듈은 다음 기능을 제공합니다:

- **와일드카드 인증서**: `*.set-of.com` 및 `set-of.com` 도메인을 위한 SSL/TLS 인증서
- **자동 DNS 검증**: Route53을 통한 인증서 자동 검증
- **자동 갱신**: AWS ACM의 자동 갱신 기능 활용
- **만료 모니터링**: CloudWatch 알람을 통한 인증서 만료 감지
- **다중 서비스 지원**: ALB, CloudFront 등 다양한 AWS 서비스에서 사용 가능

## 전제 조건

- Route53 호스팅 영역이 미리 구성되어 있어야 합니다 (`terraform/route53`)
- DNS 레코드 생성 권한 필요
- CloudWatch 알람 생성 권한 필요

## 사용 방법

### 기본 사용

```hcl
module "acm" {
  source = "./terraform/acm"

  domain_name              = "set-of.com"
  environment              = "prod"
  enable_expiration_alarm  = true

  tags = {
    Project = "platform-infrastructure"
  }
}
```

### 출력값 사용

```hcl
# ALB에서 인증서 사용
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = module.acm.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# CloudFront에서 인증서 사용
resource "aws_cloudfront_distribution" "main" {
  # ... other configuration ...

  viewer_certificate {
    acm_certificate_arn      = module.acm.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws_region | AWS 리전 (CloudFront용은 us-east-1 필요) | `string` | `"ap-northeast-2"` | no |
| environment | 환경 이름 (prod, staging, dev) | `string` | `"prod"` | no |
| domain_name | 인증서를 생성할 도메인 이름 | `string` | `"set-of.com"` | no |
| route53_zone_id | Route53 Hosted Zone ID (DNS 검증용). 미제공시 SSM Parameter Store에서 자동 조회 (`/shared/route53/hosted-zone-id`) | `string` | `""` | no |
| enable_expiration_alarm | 인증서 만료 CloudWatch 알람 활성화 | `bool` | `true` | no |
| tags | 추가 태그 | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| certificate_arn | 인증서 ARN (ALB, CloudFront 등에서 사용) |
| certificate_id | 인증서 ID |
| certificate_domain_name | 인증서 도메인 이름 |
| certificate_status | 인증서 상태 |
| certificate_subject_alternative_names | SANs 목록 |
| certificate_validation_method | 인증서 검증 방법 |
| certificate_not_after | 인증서 만료일 |
| certificate_not_before | 인증서 시작일 |
| validation_record_fqdns | DNS 검증 레코드 FQDN |
| expiration_alarm_arn | 만료 알람 ARN |

## 주요 기능

### 1. 와일드카드 인증서

도메인(`set-of.com`)과 모든 서브도메인(`*.set-of.com`)을 커버하는 단일 인증서:

```hcl
resource "aws_acm_certificate" "wildcard" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
}
```

### 2. 자동 DNS 검증

Route53을 통해 인증서 검증 레코드가 자동으로 생성되고 검증됩니다:

```hcl
resource "aws_route53_record" "certificate_validation" {
  # 자동으로 생성되는 DNS 검증 레코드
}

resource "aws_acm_certificate_validation" "wildcard" {
  # 검증 완료 대기 (최대 10분)
}
```

### 3. 자동 갱신 모니터링

AWS ACM은 인증서를 자동으로 갱신하지만, 만료 30일 전에 알람을 발생시킵니다:

```hcl
resource "aws_cloudwatch_metric_alarm" "certificate-expiration" {
  metric_name = "days-to-expiry"
  threshold   = 30  # 30일 미만일 때 알람
}
```

## 배포

### 1. 초기화

```bash
cd terraform/acm
terraform init
```

### 2. 계획 검토

```bash
terraform plan
```

### 3. 적용

```bash
terraform apply
```

### 4. 검증

```bash
# 인증서 상태 확인
terraform output certificate_status

# 인증서 ARN 확인 (다른 서비스에서 사용)
terraform output certificate_arn
```

## CloudFront 사용 시 주의사항

CloudFront에서 ACM 인증서를 사용하려면 **반드시 us-east-1 리전**에서 생성해야 합니다:

```hcl
# CloudFront용 인증서 별도 생성
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "acm_cloudfront" {
  source = "./terraform/acm"

  providers = {
    aws = aws.us-east-1
  }

  aws_region = "us-east-1"
  domain_name = "set-of.com"
}
```

## 보안 및 거버넌스

### 필수 태그

모든 리소스는 `local.required_tags`를 사용하여 태그가 적용됩니다:

```hcl
tags = merge(
  local.required_tags,
  {
    Name      = "acm-wildcard-${var.domain_name}"
    Component = "acm"
  }
)
```

### 보안 스캔 통과

- ✅ tfsec: 보안 베스트 프랙티스 준수
- ✅ checkov: CIS AWS, PCI-DSS, HIPAA, ISO/IEC 27001 준수

## 트러블슈팅

### 인증서 검증이 완료되지 않는 경우

```bash
# Route53 호스팅 영역 확인
aws route53 list-hosted-zones

# DNS 검증 레코드 확인
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>

# ACM 인증서 상태 확인
aws acm describe-certificate --certificate-arn <cert-arn>
```

### 인증서가 만료 예정인 경우

AWS ACM은 인증서를 자동으로 갱신합니다. 단, DNS 검증 레코드가 여전히 존재해야 합니다:

1. Route53에서 검증 레코드가 존재하는지 확인
2. 인증서 상태가 "ISSUED"인지 확인
3. 갱신이 실패하면 AWS Support에 문의

## 리소스

- [AWS ACM 문서](https://docs.aws.amazon.com/acm/)
- [Terraform AWS ACM Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate)
- [인증서 자동 갱신](https://docs.aws.amazon.com/acm/latest/userguide/managed-renewal.html)

## 관련 모듈

- `terraform/route53`: Route53 호스팅 영역 (선행 필수)
- `terraform/atlantis`: ALB와 함께 인증서 사용 예시
- `terraform/monitoring`: CloudWatch 알람 설정

## 작성자

- Platform Team
