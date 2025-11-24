# Route53 스택

AWS Route53 Hosted Zone, DNS Query Logging, Health Checks를 관리하는 프로덕션 환경 스택입니다. KMS 암호화된 CloudWatch Logs와 함께 DNS 쿼리 로깅 및 서비스 상태 모니터링을 제공합니다.

## 주요 기능

- **Hosted Zone 관리**: set-of.com 도메인의 DNS 호스팅 영역 관리
- **DNS Query Logging**: CloudWatch Logs를 통한 모든 DNS 쿼리 로깅 및 분석
- **KMS 암호화**: 고객 관리형 KMS 키를 사용한 로그 데이터 암호화
- **Health Checks**: Atlantis 서버의 가용성 모니터링
- **SSM 파라미터**: 크로스 스택 참조를 위한 Hosted Zone ID 저장
- **라이프사이클 보호**: 실수로 인한 Hosted Zone 삭제 방지

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│ Route53 Hosted Zone (set-of.com)                                │
│                                                                   │
│  ┌────────────────┐         ┌──────────────────────┐            │
│  │ DNS Records    │────────▶│ Query Logging        │            │
│  │ - A Records    │         │ - CloudWatch Logs    │            │
│  │ - CNAME        │         │ - KMS Encrypted      │            │
│  │ - Alias        │         │ - 7 days retention   │            │
│  └────────────────┘         └──────────────────────┘            │
│                                                                   │
│  ┌────────────────┐         ┌──────────────────────┐            │
│  │ Health Checks  │         │ SSM Parameters       │            │
│  │ - Atlantis     │         │ - Hosted Zone ID     │            │
│  │   (HTTPS/443)  │         │ - Cross-stack refs   │            │
│  └────────────────┘         └──────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## 구성 요소

### 1. Route53 Hosted Zone
- **도메인**: set-of.com
- **타입**: Public Hosted Zone
- **라이프사이클**: `prevent_destroy = true` (삭제 방지)
- **용도**: 모든 DNS 레코드 관리

### 2. DNS Query Logging
- **로그 그룹**: `/aws/route53/set-of.com`
- **보존 기간**: 7일 (로깅 표준 준수)
- **암호화**: KMS 고객 관리형 키
- **활성화**: 기본적으로 활성화 (`enable_query_logging = true`)

### 3. KMS 암호화
- **키 설명**: Route53 query logs encryption
- **키 로테이션**: 자동 활성화
- **삭제 대기 기간**: 30일
- **별칭**: `alias/route53-logs`

### 4. Health Checks
- **대상**: atlantis.set-of.com
- **프로토콜**: HTTPS (포트 443)
- **엔드포인트**: `/healthz`
- **실패 임계값**: 3회 연속 실패
- **체크 간격**: 30초

### 5. SSM 파라미터
- **파라미터 이름**: `/shared/route53/hosted-zone-id`
- **타입**: String
- **용도**: ACM 인증서 검증 등 다른 스택에서 참조

## 사용 중인 모듈

이 스택은 AWS 리소스를 직접 관리하며, 별도의 커스텀 모듈을 사용하지 않습니다.

**참고**: `../../modules/route53-record` 모듈은 존재하지만 현재 스택에서 사용되지 않습니다. DNS 레코드는 각 서비스 스택(ALB, Atlantis 등)에서 관리합니다.

## 배포 방법

### 1. Hosted Zone 임포트 (최초 1회만)

기존 Hosted Zone이 이미 AWS Console에 존재하는 경우:

```bash
# Hosted Zone ID 확인
aws route53 list-hosted-zones | grep set-of.com

# Terraform으로 임포트
cd terraform/environments/prod/route53
terraform import aws_route53_zone.primary <ZONE_ID>
```

### 2. 초기화 및 계획

```bash
cd terraform/environments/prod/route53

# Terraform 초기화
terraform init

# 변경 사항 확인
terraform plan
```

### 3. 배포

```bash
# 프로덕션 배포 (CI/CD 파이프라인 권장)
terraform apply

# 또는 자동 승인
terraform apply -auto-approve
```

### 4. 배포 검증

```bash
# Hosted Zone 확인
aws route53 get-hosted-zone --id <ZONE_ID>

# Name Servers 확인
aws route53 get-hosted-zone --id <ZONE_ID> --query "DelegationSet.NameServers"

# Query Logging 상태 확인
aws route53 list-query-logging-configs --hosted-zone-id <ZONE_ID>

# Health Check 상태 확인
aws route53 get-health-check-status --health-check-id <HEALTH_CHECK_ID>
```

## 주요 변수

### 필수 변수 (태깅)

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `environment` | "prod" | 환경 이름 |
| `service_name` | "dns" | 서비스 이름 |
| `team` | "platform-team" | 담당 팀 |
| `owner` | "platform@ryuqqq.com" | 리소스 소유자 |
| `cost_center` | "infrastructure" | 비용 센터 |
| `project` | "infrastructure" | 프로젝트 이름 |
| `data_class` | "public" | 데이터 분류 (DNS는 public) |

### Route53 구성 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `aws_region` | "ap-northeast-2" | AWS 리전 |
| `domain_name` | "set-of.com" | 주요 도메인 이름 |
| `enable_dnssec` | false | DNSSEC 활성화 (미구현) |
| `enable_query_logging` | true | 쿼리 로깅 활성화 |

## 출력 값

| 출력 | 설명 | 사용 예시 |
|------|------|-----------|
| `hosted_zone_id` | Hosted Zone ID | ACM 인증서 검증, DNS 레코드 생성 |
| `hosted_zone_name` | Hosted Zone 이름 | "set-of.com" |
| `name_servers` | Name Server 목록 | 도메인 등록 업체에서 NS 레코드 설정 |
| `zone_arn` | Hosted Zone ARN | IAM 정책 참조 |
| `atlantis_health_check_id` | Atlantis Health Check ID | CloudWatch 알람 설정 |
| `query_log_group_name` | CloudWatch Log Group 이름 | 로그 조회 |
| `query_log_group_arn` | CloudWatch Log Group ARN | IAM 정책 참조 |

## 출력 값 사용 예시

```hcl
# 다른 스택에서 Hosted Zone ID 참조
data "aws_ssm_parameter" "hosted_zone_id" {
  name = "/shared/route53/hosted-zone-id"
}

# ACM 인증서 검증
resource "aws_acm_certificate" "main" {
  domain_name       = "*.set-of.com"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_ssm_parameter.hosted_zone_id.value
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}
```

## 거버넌스 준수

### 필수 태그
모든 리소스는 다음 필수 태그를 포함합니다:
- `Owner`: 리소스 소유자 식별
- `CostCenter`: 비용 추적 및 청구
- `Environment`: 환경 분리 (prod)
- `Lifecycle`: 리소스 수명 주기 (permanent)
- `DataClass`: 데이터 분류 (public)
- `Service`: 서비스 식별 (dns)

### KMS 암호화
- CloudWatch Logs는 고객 관리형 KMS 키로 암호화됩니다
- KMS 키는 자동 로테이션이 활성화되어 있습니다
- 키 정책은 CloudWatch Logs 서비스만 접근 가능하도록 제한됩니다

### 네이밍 규칙
- 리소스 이름: kebab-case (예: `route53-logs-encryption`)
- 변수 및 로컬: snake_case (예: `enable_query_logging`)
- KMS 별칭: `alias/route53-logs`

### 로그 보존
- CloudWatch Logs: 7일 보존 (로깅 표준 준수)
- 장기 보관이 필요한 경우 S3 아카이빙 구성 필요

## 운영 가이드

### Name Server 확인 및 설정

```bash
# Name Server 조회
terraform output name_servers

# 또는 AWS CLI 사용
aws route53 get-hosted-zone \
  --id $(terraform output -raw hosted_zone_id) \
  --query "DelegationSet.NameServers"
```

도메인 등록 업체(예: GoDaddy, Gabia)에서 위 Name Server를 NS 레코드로 설정해야 합니다.

### DNS Query Logs 조회

```bash
# CloudWatch Logs Insights 쿼리
aws logs start-query \
  --log-group-name "/aws/route53/set-of.com" \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string "fields @timestamp, query_name, query_type, rcode | sort @timestamp desc | limit 100"

# 특정 도메인 쿼리 필터링
aws logs filter-log-events \
  --log-group-name "/aws/route53/set-of.com" \
  --filter-pattern "atlantis.set-of.com"
```

### Health Check 모니터링

```bash
# Health Check 상태 확인
aws route53 get-health-check-status \
  --health-check-id $(terraform output -raw atlantis_health_check_id)

# Health Check 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/Route53 \
  --metric-name HealthCheckStatus \
  --dimensions Name=HealthCheckId,Value=$(terraform output -raw atlantis_health_check_id) \
  --start-time $(date -u -d '1 hour ago' --iso-8601=seconds) \
  --end-time $(date -u --iso-8601=seconds) \
  --period 300 \
  --statistics Average
```

### DNS 레코드 추가 (다른 스택에서)

DNS 레코드는 각 서비스 스택에서 직접 관리합니다:

```hcl
# 예: ALB 스택에서 A 레코드 추가
data "aws_ssm_parameter" "hosted_zone_id" {
  name = "/shared/route53/hosted-zone-id"
}

resource "aws_route53_record" "service" {
  zone_id = data.aws_ssm_parameter.hosted_zone_id.value
  name    = "api.set-of.com"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
```

### KMS 키 로테이션 확인

```bash
# KMS 키 정보 확인
aws kms describe-key \
  --key-id alias/route53-logs \
  --query 'KeyMetadata.[KeyId,KeyRotationEnabled,KeyState]'

# 키 로테이션 상태 확인
aws kms get-key-rotation-status \
  --key-id alias/route53-logs
```

## 보안 고려사항

### DNSSEC
현재 DNSSEC은 활성화되지 않았습니다 (`enable_dnssec = false`). DNSSEC를 활성화하려면:

1. Route53에서 DNSSEC 서명 활성화
2. 도메인 등록 업체에 DS 레코드 추가
3. TTL 및 키 로테이션 정책 설정

**주의**: DNSSEC 활성화는 신중하게 계획해야 하며, 잘못 구성하면 도메인 전체가 접근 불가할 수 있습니다.

### Query Logging 데이터 보호
- CloudWatch Logs는 KMS로 암호화됩니다
- 로그에는 민감한 DNS 쿼리 정보가 포함될 수 있습니다
- 로그 접근 권한은 최소 권한 원칙을 따릅니다
- 7일 후 자동 삭제되므로 장기 보관 시 S3 아카이빙 필요

### Health Check 알람 설정

현재 Health Check는 생성되었지만 CloudWatch 알람은 설정되지 않았습니다. 알람 추가 권장:

```hcl
resource "aws_cloudwatch_metric_alarm" "atlantis_health" {
  alarm_name          = "route53-atlantis-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = "60"
  statistic           = "Minimum"
  threshold           = "1"
  alarm_description   = "Atlantis health check failed"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.atlantis.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

### 접근 제어
- Hosted Zone 수정은 Terraform을 통해서만 수행
- 수동 변경은 Terraform 상태와 불일치 발생 가능
- IAM 정책으로 Route53 접근 제한 필요

## 비용 최적화

### Route53 비용 구성
- **Hosted Zone**: $0.50/월 (hosted zone당)
- **DNS 쿼리**: 처음 10억 건은 $0.40/100만 건
- **Health Checks**: $0.50/월 (health check당)
- **Query Logging**: CloudWatch Logs 비용 ($0.50/GB 인제스트)

### 비용 절감 팁
- Query Logging은 필요한 경우에만 활성화 (`enable_query_logging = false`)
- 로그 보존 기간 최소화 (7일 기본값)
- 불필요한 Health Check 제거
- DNS 쿼리 TTL 최적화로 쿼리 수 감소

### 비용 모니터링

```bash
# CloudWatch Logs 사용량 확인
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/route53" \
  --query "logGroups[*].[logGroupName,storedBytes]" \
  --output table

# Cost Explorer로 Route53 비용 조회
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --filter file://route53-filter.json
```

## 문제 해결

### 일반적인 문제

**문제**: `Error: deleting Route53 Hosted Zone: HostedZoneNotEmpty`
- **원인**: Hosted Zone에 DNS 레코드가 남아있음
- **해결**: 모든 DNS 레코드를 먼저 삭제 (NS, SOA 제외)
- **참고**: 현재 `prevent_destroy = true`로 설정되어 Terraform으로 삭제 불가

**문제**: `Error: creating Route53 Query Logging Config: InvalidInput`
- **원인**: CloudWatch Log Group이 생성되지 않음
- **해결**: KMS 키와 Log Group 생성 확인, 의존성 순서 확인

**문제**: Health Check가 실패 상태
- **원인**: 대상 서버가 다운되었거나 `/healthz` 엔드포인트 없음
- **해결**: 대상 서버 상태 확인, Health Check 설정(포트, 경로) 검토

**문제**: Name Server 변경이 반영되지 않음
- **원인**: DNS 전파 지연 (최대 48시간)
- **해결**: `dig` 또는 `nslookup`으로 NS 레코드 확인, 전파 대기

### 디버깅 팁

```bash
# Hosted Zone 상세 정보 확인
aws route53 get-hosted-zone --id <ZONE_ID>

# DNS 레코드 목록 조회
aws route53 list-resource-record-sets --hosted-zone-id <ZONE_ID>

# Query Logging 설정 확인
aws route53 list-query-logging-configs

# Health Check 설정 확인
aws route53 get-health-check --health-check-id <HEALTH_CHECK_ID>

# KMS 키 정책 확인
aws kms get-key-policy --key-id alias/route53-logs --policy-name default

# CloudWatch Logs 스트림 확인
aws logs describe-log-streams \
  --log-group-name "/aws/route53/set-of.com" \
  --order-by LastEventTime \
  --descending
```

## 제약사항

- Hosted Zone 이름은 생성 후 변경 불가 (재생성 필요)
- `prevent_destroy = true`로 설정되어 Terraform으로 삭제 불가
- Query Logging은 Public Hosted Zone만 지원 (Private Zone 미지원)
- Health Check는 AWS 외부 엔드포인트만 모니터링 가능
- KMS 키는 동일 리전에 있어야 함
- CloudWatch Logs는 us-east-1 리전에서만 Route53 Query Logging 지원 (현재 ap-northeast-2 사용 중이므로 로그는 리전별로 생성)

## 요구사항

### Terraform 버전
- Terraform >= 1.0

### 프로바이더 버전
- AWS Provider >= 4.0

### 필수 리소스
- 없음 (Hosted Zone은 임포트 또는 새로 생성)

### 필수 권한
- `route53:*` (Hosted Zone, Health Check 관리)
- `logs:*` (CloudWatch Logs 관리)
- `kms:*` (KMS 키 생성 및 관리)
- `ssm:PutParameter` (SSM 파라미터 생성)

## 관련 스택

- **alb**: ALB DNS 레코드 생성 시 Hosted Zone ID 참조
- **atlantis**: Atlantis DNS 레코드 및 ACM 인증서 검증
- **acm**: SSL/TLS 인증서 DNS 검증

## 참고 자료

- [AWS Route53 공식 문서](https://docs.aws.amazon.com/route53/)
- [Route53 Query Logging](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/query-logs.html)
- [Route53 Health Checks](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks.html)
- [DNSSEC in Route53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-configure-dnssec.html)

## 라이선스

이 스택은 내부 인프라 프로젝트의 일부입니다.

## 작성자

Platform Team

## 변경 이력

주요 변경 사항은 [CHANGELOG.md](../../../docs/changelogs/CHANGELOG_INFRASTRUCTURE.md)를 참조하세요.
