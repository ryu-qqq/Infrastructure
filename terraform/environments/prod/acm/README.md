# Production SSL/TLS Certificate Management

**버전**: 1.0.0
**환경**: Production
**리전**: ap-northeast-2 (Seoul)

> **중요**: 이 스택은 모듈을 사용하지 않고 raw Terraform 리소스로 구성되었습니다.
> AWS Certificate Manager (ACM)를 사용하여 SSL/TLS 인증서를 관리합니다.

---

## 📋 목차

- [개요](#개요)
- [아키텍처](#아키텍처)
- [인증서 구성](#인증서-구성)
- [리소스 목록](#리소스-목록)
- [변수 설정](#변수-설정)
- [출력값](#출력값)
- [배포 방법](#배포-방법)
- [운영 가이드](#운영-가이드)
- [문제 해결](#문제-해결)

---

## 개요

Production 환경의 SSL/TLS 인증서를 AWS Certificate Manager (ACM)로 관리하는 Terraform 스택입니다.

### 주요 특징

- **와일드카드 인증서**: `*.set-of.com` 및 `set-of.com` 도메인을 커버하는 단일 인증서
- **자동 DNS 검증**: Route53을 통한 인증서 자동 검증 및 발급
- **자동 갱신**: AWS ACM의 자동 갱신 기능으로 만료 걱정 없음
- **만료 모니터링**: CloudWatch 알람을 통한 갱신 프로세스 모니터링
- **SSM Parameter 통합**: 다른 스택에서 인증서 ARN을 쉽게 참조 가능
- **Multi-Service 지원**: ALB, CloudFront, API Gateway 등에서 사용 가능

### 사용 모듈

- **없음** (모든 리소스가 raw Terraform 리소스)

---

## 아키텍처

### 인증서 발급 프로세스

```
┌──────────────────────────────────────────────────────────────────┐
│                     ACM Certificate Request                       │
│                                                                    │
│  1. 인증서 요청 (domain_name: set-of.com)                          │
│     └─> SANs: *.set-of.com                                        │
│                                                                    │
│  2. DNS 검증 방식 선택 (validation_method: DNS)                    │
│     └─> AWS가 검증용 DNS 레코드 생성 요청                          │
│                                                                    │
│  3. Route53에 검증 레코드 자동 생성                                │
│     └─> _xxxxx.set-of.com CNAME _yyyyy.acm-validations.aws       │
│                                                                    │
│  4. AWS ACM이 DNS 레코드 확인 (최대 10분 소요)                     │
│     └─> 검증 성공 시 인증서 발급                                   │
│                                                                    │
│  5. 인증서 자동 갱신 (만료 60일 전부터 시작)                        │
│     └─> DNS 검증 레코드가 유지되는 한 자동 갱신                     │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

### 인증서 사용 구조

```
                    ┌─────────────────────┐
                    │   ACM Certificate   │
                    │  (*.set-of.com)     │
                    └──────────┬──────────┘
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
    ┌───────▼────────┐ ┌──────▼───────┐ ┌───────▼────────┐
    │      ALB       │ │  CloudFront  │ │  API Gateway   │
    │   (HTTPS)      │ │   (HTTPS)    │ │    (Custom)    │
    └────────────────┘ └──────────────┘ └────────────────┘
```

### 모니터링 구조

```
┌──────────────────────────────────────────────────────────────────┐
│                    Certificate Monitoring                         │
│                                                                    │
│  ACM Certificate                                                   │
│       │                                                            │
│       ├─> Metric: days-to-expiry                                  │
│       │                                                            │
│       └─> CloudWatch Alarm                                        │
│           ├─> Threshold: < 30 days                                │
│           ├─> Period: 1 day                                       │
│           └─> Action: SNS notification (선택 사항)                 │
│                                                                    │
│  정상 상태: ACM이 만료 60일 전부터 자동 갱신 시작                   │
│  알람 발생: 갱신 프로세스에 문제가 있거나 DNS 레코드 삭제됨         │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

---

## 인증서 구성

### 도메인 커버리지

| 도메인 타입 | 도메인 이름 | 용도 |
|------------|------------|------|
| **Primary Domain** | `set-of.com` | 루트 도메인 |
| **Wildcard** | `*.set-of.com` | 모든 서브도메인 (api, www, admin 등) |

### 커버되는 도메인 예시

✅ **커버됨**:
- `set-of.com`
- `api.set-of.com`
- `www.set-of.com`
- `admin.set-of.com`
- `stage.set-of.com`

❌ **커버 안 됨**:
- `*.api.set-of.com` (2단계 와일드카드)
- `example.com` (다른 도메인)

### 검증 방법

**DNS 검증 (Recommended)**:
- Route53을 통한 자동 검증
- 검증 레코드가 유지되는 한 자동 갱신 가능
- 다운타임 없이 검증 가능

**Email 검증 (사용 안 함)**:
- 수동 이메일 확인 필요
- 갱신 시마다 재검증 필요
- 자동화 불가능

---

## 리소스 목록

### 1. ACM Certificate

**리소스**: `aws_acm_certificate.wildcard`

```hcl
resource "aws_acm_certificate" "wildcard" {
  domain_name               = "set-of.com"
  subject_alternative_names = ["*.set-of.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
```

**특징**:
- 와일드카드 인증서 (모든 서브도메인 커버)
- DNS 검증 방식 (자동 갱신 가능)
- Blue/Green 배포 지원 (`create_before_destroy`)

**인증서 수명 주기**:
1. **발급**: DNS 검증 완료 후 자동 발급 (최대 10분)
2. **유효 기간**: 13개월 (395일)
3. **갱신 시작**: 만료 60일 전부터 자동 갱신 시작
4. **갱신 완료**: 만료 전에 자동으로 새 인증서 발급

### 2. Route53 DNS Validation Records

**리소스**: `aws_route53_record.certificate-validation`

```hcl
resource "aws_route53_record" "certificate-validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.route53_zone_id
}
```

**특징**:
- ACM이 자동으로 생성한 검증 정보를 Route53에 등록
- `allow_overwrite = true`로 기존 레코드 덮어쓰기 허용
- `for_each`로 여러 도메인 검증 레코드 자동 생성 (wildcard는 2개 생성)

**생성되는 레코드 예시**:
```
_xxxxxxxxxxxx.set-of.com.     CNAME  _yyyyyyyyyyyy.acm-validations.aws.
_xxxxxxxxxxxx.*.set-of.com.   CNAME  _yyyyyyyyyyyy.acm-validations.aws.
```

### 3. Certificate Validation

**리소스**: `aws_acm_certificate_validation.wildcard`

```hcl
resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate-validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}
```

**특징**:
- DNS 검증이 완료될 때까지 대기 (최대 10분)
- 검증 완료 후 `terraform apply`가 완료됨
- 검증 실패 시 timeout 에러 발생

### 4. CloudWatch Expiration Alarm

**리소스**: `aws_cloudwatch_metric_alarm.certificate-expiration[0]`

**활성화 조건**: `var.enable_expiration_alarm = true`

```hcl
resource "aws_cloudwatch_metric_alarm" "certificate-expiration" {
  count = var.enable_expiration_alarm ? 1 : 0

  alarm_name          = "acm-certificate-expiration-set-of.com"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "days-to-expiry"
  namespace           = "AWS/CertificateManager"
  period              = 86400  # 1 day
  statistic           = "Minimum"
  threshold           = 30     # Alert when less than 30 days to expiry
  alarm_description   = "ACM certificate for set-of.com is expiring in less than 30 days"
  treat_missing_data  = "notBreaching"

  dimensions = {
    CertificateArn = aws_acm_certificate.wildcard.arn
  }
}
```

**특징**:
- **모니터링 메트릭**: `days-to-expiry` (만료까지 남은 일수)
- **알람 임계값**: 30일 미만
- **평가 주기**: 1일 1회
- **목적**: ACM 자동 갱신 프로세스 모니터링

**알람이 발생하는 경우**:
- DNS 검증 레코드가 삭제됨
- Route53 호스팅 영역이 삭제됨
- AWS ACM 갱신 프로세스에 문제 발생

**정상 운영 시**:
- ACM이 만료 60일 전부터 자동 갱신
- 알람은 거의 발생하지 않음
- 발생 시 즉시 대응 필요 (DNS 레코드 복구)

### 5. Route53 Zone ID Resolution (Cross-Stack Reference)

**Data Source**: `data.aws_ssm_parameter.route53-zone-id[0]`

```hcl
data "aws_ssm_parameter" "route53-zone-id" {
  count = var.route53_zone_id == "" ? 1 : 0
  name  = "/shared/route53/hosted-zone-id"
}

locals {
  route53_zone_id = var.route53_zone_id != "" ? var.route53_zone_id : data.aws_ssm_parameter.route53-zone-id[0].value
}
```

**특징**:
- SSM Parameter Store에서 Route53 호스팅 영역 ID 자동 조회
- 프로젝트의 Cross-Stack Reference 패턴 준수
- Atlantis가 `Route53:ListHostedZones` 권한 불필요

**참조 경로**: `/shared/route53/hosted-zone-id`

---

## 변수 설정

### 필수 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `environment` | `string` | `prod` | 환경 이름 |
| `aws_region` | `string` | `ap-northeast-2` | AWS 리전 (CloudFront용은 us-east-1 필요) |

### 인증서 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `domain_name` | `string` | `set-of.com` | 인증서를 발급할 도메인 이름 |
| `route53_zone_id` | `string` | `""` | Route53 호스팅 영역 ID (미제공 시 SSM에서 자동 조회) |
| `enable_expiration_alarm` | `bool` | `true` | CloudWatch 만료 알람 활성화 여부 |

### 거버넌스 태그 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `service` | `string` | `certificate-management` | 서비스 이름 (Service 태그) |
| `owner` | `string` | `fbtkdals2@naver.com` | 리소스 소유자 (Owner 태그) |
| `cost_center` | `string` | `infrastructure` | 비용 센터 (CostCenter 태그) |
| `managed_by` | `string` | `terraform` | 관리 방법 (ManagedBy 태그) |
| `project` | `string` | `infrastructure` | 프로젝트 이름 (Project 태그) |
| `data_class` | `string` | `confidential` | 데이터 분류 (DataClass 태그) |
| `additional_tags` | `map(string)` | `{}` | 추가 커스텀 태그 |

---

## 출력값

### 인증서 정보

| 출력명 | 설명 | 사용 예시 |
|--------|------|----------|
| `certificate_arn` | 인증서 ARN | ALB, CloudFront, API Gateway에서 사용 |
| `certificate_id` | 인증서 ID | AWS CLI 작업용 |
| `certificate_domain_name` | 인증서 도메인 이름 | `set-of.com` |
| `certificate_status` | 인증서 상태 | `ISSUED`, `PENDING_VALIDATION` |
| `certificate_subject_alternative_names` | SANs 목록 | `["*.set-of.com"]` |
| `certificate_validation_method` | 검증 방법 | `DNS` |
| `certificate_not_after` | 인증서 만료일 | 모니터링용 |
| `certificate_not_before` | 인증서 시작일 | 모니터링용 |

### 검증 정보

| 출력명 | 설명 |
|--------|------|
| `validation_record_fqdns` | DNS 검증 레코드 FQDN 목록 |

### 모니터링 정보

| 출력명 | 설명 |
|--------|------|
| `expiration_alarm_arn` | 만료 알람 ARN (활성화 시) |

### 다른 스택에서 참조 예시

#### ALB에서 인증서 사용

```hcl
# terraform/environments/prod/atlantis/main.tf

data "aws_ssm_parameter" "certificate_arn" {
  name = "/shared/acm/certificate-arn"
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_ssm_parameter.certificate_arn.value

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
```

#### CloudFront에서 인증서 사용

```hcl
# CloudFront는 us-east-1 리전의 인증서만 사용 가능

data "aws_ssm_parameter" "certificate_arn" {
  name     = "/shared/acm/certificate-arn-cloudfront"
  provider = aws.us-east-1
}

resource "aws_cloudfront_distribution" "main" {
  viewer_certificate {
    acm_certificate_arn      = data.aws_ssm_parameter.certificate_arn.value
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
```

---

## 배포 방법

### 1. 사전 준비

#### 선행 요구사항

**Route53 호스팅 영역 필수**:
```bash
# Route53 스택을 먼저 배포해야 함
cd terraform/environments/prod/route53
terraform apply
```

Route53 스택이 배포되면 SSM Parameter에 호스팅 영역 ID가 자동 저장됩니다:
- Parameter: `/shared/route53/hosted-zone-id`

#### AWS Credentials 설정

```bash
export AWS_PROFILE=prod
export AWS_REGION=ap-northeast-2
```

#### Terraform 초기화

```bash
cd terraform/environments/prod/acm
terraform init
```

### 2. 배포 전 검증

#### 코드 포맷팅

```bash
terraform fmt
```

#### 코드 검증

```bash
terraform validate
```

#### 변경 사항 미리보기

```bash
terraform plan
```

### 3. 배포 실행

#### 기본 배포 (만료 알람 활성화)

```bash
terraform apply
```

#### 만료 알람 비활성화

```bash
terraform apply -var="enable_expiration_alarm=false"
```

#### 특정 변수 파일 사용

```bash
terraform apply -var-file="prod.tfvars"
```

### 4. 배포 후 확인

#### 인증서 상태 확인

```bash
# Terraform output으로 확인
terraform output certificate_status

# AWS CLI로 확인
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw certificate_arn) \
  --region ap-northeast-2
```

#### DNS 검증 레코드 확인

```bash
# Route53 레코드 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id $(aws ssm get-parameter --name /shared/route53/hosted-zone-id --query 'Parameter.Value' --output text) \
  --region ap-northeast-2 \
  | jq '.ResourceRecordSets[] | select(.Type == "CNAME") | select(.Name | contains("acm-validations"))'
```

#### CloudWatch 알람 확인

```bash
aws cloudwatch describe-alarms \
  --alarm-names "acm-certificate-expiration-set-of.com" \
  --region ap-northeast-2
```

#### 인증서 만료일 확인

```bash
terraform output certificate_not_after
```

---

## 운영 가이드

### 인증서 자동 갱신

#### ACM 자동 갱신 프로세스

AWS ACM은 다음 조건을 만족하면 자동으로 인증서를 갱신합니다:

**1. 갱신 시작 시점**: 만료 60일 전
**2. 필수 조건**:
   - DNS 검증 레코드가 Route53에 유지되어야 함
   - Route53 호스팅 영역이 활성 상태여야 함
   - 도메인 소유권이 유지되어야 함

**3. 갱신 완료**: 만료 전에 자동으로 새 인증서 발급

#### 갱신 상태 모니터링

```bash
# CloudWatch 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/CertificateManager \
  --metric-name DaysToExpiry \
  --dimensions Name=CertificateArn,Value=$(terraform output -raw certificate_arn) \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Minimum \
  --region ap-northeast-2
```

**정상 상태**:
- `DaysToExpiry` 메트릭이 60일 이하로 떨어지면 갱신 시작
- 며칠 내로 다시 365일 이상으로 올라감
- CloudWatch 알람이 발생하지 않음

**문제 상태**:
- `DaysToExpiry`가 30일 이하로 떨어짐
- CloudWatch 알람 발생
- DNS 검증 레코드 확인 필요

### 새 도메인 추가

#### 1. 서브도메인 추가 (와일드카드로 커버됨)

기존 와일드카드 인증서가 모든 서브도메인을 커버하므로 **추가 작업 불필요**:

```
✅ api.set-of.com        (이미 커버됨)
✅ admin.set-of.com      (이미 커버됨)
✅ stage.set-of.com      (이미 커버됨)
```

#### 2. 새로운 루트 도메인 추가

새로운 루트 도메인 (예: `example.com`)을 추가하려면 **별도 인증서 생성 필요**:

```hcl
# 새 인증서 리소스 추가
resource "aws_acm_certificate" "example_com" {
  domain_name               = "example.com"
  subject_alternative_names = ["*.example.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "acm-wildcard-example.com"
      Component = "acm"
      Domain    = "example.com"
      Type      = "wildcard"
    }
  )
}
```

### CloudFront용 인증서 생성

CloudFront는 **us-east-1 리전의 인증서만** 사용 가능합니다.

#### 별도 스택 생성 (권장)

```bash
# CloudFront용 별도 스택
mkdir -p terraform/environments/prod/acm-cloudfront
cd terraform/environments/prod/acm-cloudfront

# us-east-1 리전으로 설정
cat > terraform.tfvars <<EOF
aws_region = "us-east-1"
domain_name = "set-of.com"
enable_expiration_alarm = true
EOF

terraform init
terraform apply
```

#### Provider Alias 사용 (대안)

```hcl
# providers.tf
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# main.tf
module "acm_cloudfront" {
  source = "../../../modules/acm"  # 모듈화 필요

  providers = {
    aws = aws.us-east-1
  }

  aws_region  = "us-east-1"
  domain_name = "set-of.com"
}
```

### 인증서 교체 (Blue/Green Deployment)

`create_before_destroy` lifecycle 덕분에 안전한 교체가 가능합니다.

#### 교체 시나리오

**변경 사항**:
- 도메인 이름 변경
- 검증 방법 변경
- 리소스 재생성 필요

**교체 프로세스**:
```bash
# 1. 새 인증서 생성 계획 확인
terraform plan

# 2. 새 인증서 먼저 생성, 기존 인증서 나중에 삭제
terraform apply

# 3. 서비스에서 새 인증서 사용 확인
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw certificate_arn)
```

**주의사항**:
- ALB, CloudFront 등 서비스에서 인증서 ARN이 자동으로 업데이트되지 않음
- SSM Parameter를 통해 참조하면 자동 업데이트 가능
- 수동으로 ARN을 하드코딩한 경우 직접 변경 필요

### 비용 최적화

#### ACM 인증서 비용

**무료**:
- ✅ ACM 인증서 발급 및 갱신
- ✅ DNS 검증 레코드
- ✅ CloudWatch 메트릭 (기본)

**유료**:
- ⚠️ CloudWatch 알람: $0.10/월 (알람 1개당)
- ⚠️ Route53 호스팅 영역: $0.50/월
- ⚠️ Route53 DNS 쿼리: $0.40/백만 쿼리

**비용 절감 팁**:
1. 와일드카드 인증서로 여러 서브도메인을 커버 (추가 인증서 불필요)
2. CloudWatch 알람 비활성화 (ACM 자동 갱신 신뢰 시)
3. 사용하지 않는 인증서 삭제

### 보안 강화

#### TLS 프로토콜 버전 제한

ALB, CloudFront 등에서 **TLS 1.2 이상만** 허용하도록 설정:

```hcl
# ALB Listener
resource "aws_lb_listener" "https" {
  # ...
  ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  viewer_certificate {
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
```

#### HSTS (HTTP Strict Transport Security) 활성화

```hcl
# ALB Target Group
resource "aws_lb_target_group" "main" {
  health_check {
    protocol = "HTTPS"
  }
}

# CloudFront Response Headers.txt Policy
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "security-headers-policy"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = false
    }
  }
}
```

---

## 문제 해결

### 1. 인증서 검증이 완료되지 않음

**증상**: `terraform apply`가 10분 timeout으로 실패

```
Error: error waiting for ACM Certificate validation: timeout while waiting for resource
```

**확인 방법**:

```bash
# 1. 인증서 상태 확인
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw certificate_arn) \
  --region ap-northeast-2 \
  | jq '.Certificate.DomainValidationOptions'

# 2. Route53 검증 레코드 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id $(aws ssm get-parameter --name /shared/route53/hosted-zone-id --query 'Parameter.Value' --output text) \
  --region ap-northeast-2 \
  | jq '.ResourceRecordSets[] | select(.Type == "CNAME")'

# 3. DNS 쿼리 테스트
dig _xxxxx.set-of.com CNAME +short
```

**해결 방법**:

**원인 1: Route53 호스팅 영역이 없음**
```bash
# Route53 스택 먼저 배포
cd terraform/environments/prod/route53
terraform apply
```

**원인 2: DNS 검증 레코드가 생성되지 않음**
```bash
# 리소스 재생성
terraform destroy -target=aws_route53_record.certificate-validation
terraform apply
```

**원인 3: 네임서버 설정이 잘못됨**
```bash
# 도메인 등록 업체의 네임서버가 Route53 NS 레코드와 일치하는지 확인
aws route53 get-hosted-zone \
  --id $(aws ssm get-parameter --name /shared/route53/hosted-zone-id --query 'Parameter.Value' --output text) \
  | jq '.DelegationSet.NameServers'

# 도메인 등록 업체에서 네임서버 변경
# 예: GoDaddy, Namecheap, Cloudflare 등
```

**원인 4: DNS 전파 지연**
```bash
# DNS 전파 상태 확인 (최대 48시간 소요)
nslookup _xxxxx.set-of.com 8.8.8.8
```

### 2. 인증서 갱신이 실패함

**증상**: CloudWatch 알람 발생, `DaysToExpiry < 30`

**확인 방법**:

```bash
# 1. 인증서 상태 확인
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw certificate_arn) \
  --region ap-northeast-2 \
  | jq '.Certificate | {Status, DomainValidationOptions}'

# 2. DNS 검증 레코드 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id $(aws ssm get-parameter --name /shared/route53/hosted-zone-id --query 'Parameter.Value' --output text) \
  --region ap-northeast-2 \
  | jq '.ResourceRecordSets[] | select(.Name | contains("acm-validations"))'

# 3. CloudWatch 알람 상태
aws cloudwatch describe-alarms \
  --alarm-names "acm-certificate-expiration-set-of.com" \
  --region ap-northeast-2
```

**해결 방법**:

**원인 1: DNS 검증 레코드가 삭제됨**
```bash
# Terraform으로 레코드 복구
terraform apply -target=aws_route53_record.certificate-validation
```

**원인 2: Route53 호스팅 영역이 삭제됨**
```bash
# Route53 스택 복구
cd terraform/environments/prod/route53
terraform import aws_route53_zone.main <zone-id>
terraform apply
```

**원인 3: AWS ACM 서비스 문제**
```bash
# AWS Support에 문의
# 인증서를 수동으로 갱신할 수 없으므로 AWS 지원 필요
```

**긴급 대응 (만료 임박 시)**:
```bash
# 1. 새 인증서 즉시 발급
terraform apply

# 2. 서비스에서 새 인증서 ARN으로 교체
# ALB, CloudFront 등에서 certificate_arn 업데이트

# 3. 기존 인증서는 만료 후 자동 삭제됨
```

### 3. CloudFront에서 인증서 사용 불가

**증상**: CloudFront 배포 시 인증서를 찾을 수 없음

```
Error: error creating CloudFront Distribution: InvalidViewerCertificate:
The certificate is not available in us-east-1 region
```

**확인 방법**:

```bash
# 인증서 리전 확인
aws acm list-certificates --region ap-northeast-2
aws acm list-certificates --region us-east-1
```

**해결 방법**:

**CloudFront는 us-east-1 리전의 인증서만 사용 가능**:

```bash
# us-east-1 리전에 별도 인증서 생성
cd terraform/environments/prod/acm-cloudfront

cat > terraform.tfvars <<EOF
aws_region = "us-east-1"
domain_name = "set-of.com"
EOF

terraform init
terraform apply

# CloudFront에서 새 인증서 ARN 사용
```

### 4. 여러 서비스에서 같은 인증서 사용 시 충돌

**증상**: ALB, CloudFront, API Gateway 등에서 동시 사용 시 문제

**확인 방법**:

```bash
# 인증서를 사용하는 모든 서비스 확인
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw certificate_arn) \
  --region ap-northeast-2 \
  | jq '.Certificate.InUseBy'
```

**해결 방법**:

**ACM 인증서는 여러 서비스에서 동시 사용 가능**:
- ✅ 같은 리전 내: ALB, API Gateway, Elastic Beanstalk
- ✅ us-east-1: CloudFront, API Gateway Edge

**리전별 인증서 관리**:
```hcl
# ap-northeast-2: ALB, API Gateway Regional
module "acm_regional" {
  source = "../acm"
  aws_region = "ap-northeast-2"
}

# us-east-1: CloudFront, API Gateway Edge
module "acm_cloudfront" {
  source = "../acm"
  aws_region = "us-east-1"
}
```

### 5. Terraform State 충돌

**증상**: `terraform apply` 시 state lock 에러

```
Error: Error acquiring the state lock
```

**확인 방법**:

```bash
# DynamoDB Lock 테이블 확인
aws dynamodb scan \
  --table-name terraform-lock \
  --region ap-northeast-2
```

**해결 방법**:

**원인 1: 이전 작업이 비정상 종료됨**
```bash
# Lock 강제 해제 (주의: 다른 작업이 진행 중이 아닌지 확인)
terraform force-unlock <lock-id>
```

**원인 2: 여러 사용자가 동시 작업**
```bash
# Atlantis PR workflow 사용 (권장)
# 또는 작업 시간 조율
```

---

## 보안 고려사항

### 필수 보안 설정

- [x] **DNS 검증 방식**: Email 검증 대신 DNS 검증 사용 (자동화 가능)
- [x] **자동 갱신 모니터링**: CloudWatch 알람으로 갱신 실패 조기 감지
- [x] **거버넌스 태그**: 모든 리소스에 필수 태그 적용
- [x] **Cross-Stack Reference**: SSM Parameter로 안전한 정보 공유
- [ ] **SNS 알람**: CloudWatch 알람을 SNS Topic으로 전송 (선택 사항)

### 권장 보안 설정

- [ ] **TLS 1.2+ 강제**: 서비스에서 TLS 1.0/1.1 비활성화
- [ ] **HSTS 활성화**: HTTP Strict Transport Security 헤더 추가
- [ ] **Certificate Pinning**: 모바일 앱 등에서 인증서 고정 (고급)
- [ ] **알람 통합**: PagerDuty, Slack 등으로 알람 전송
- [ ] **정기 감사**: 분기별 인증서 사용 현황 리뷰

---

## 버전 히스토리

| 버전 | 날짜 | 변경 사항 |
|------|------|-----------|
| 1.0.0 | 2024-11-24 | 초기 문서화 (modules v1.0.0 패턴 기준) |

---

## 관련 문서

- [AWS Certificate Manager 사용자 가이드](https://docs.aws.amazon.com/acm/latest/userguide/)
- [ACM 자동 갱신 문서](https://docs.aws.amazon.com/acm/latest/userguide/managed-renewal.html)
- [Terraform AWS ACM Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate)
- [Infrastructure 프로젝트 거버넌스](../../../docs/governance/)

---

**Maintained By**: Platform Team
**Last Updated**: 2024-11-24
