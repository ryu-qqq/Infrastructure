# CloudTrail 스택

AWS CloudTrail 중앙 집중식 감사 로깅 및 보안 모니터링 스택입니다. 모든 AWS API 활동을 기록하고, Athena를 통한 SQL 쿼리 분석과 실시간 보안 이벤트 알림을 제공합니다.

## 주요 기능

- **다중 리전 감사 추적**: 모든 AWS 리전의 관리 이벤트 자동 기록
- **로그 파일 무결성 검증**: CloudTrail 로그 변조 방지 및 검증
- **KMS 암호화**: 고객 관리형 KMS 키를 통한 로그 암호화
- **Athena 통합**: SQL 기반 CloudTrail 로그 분석 환경
- **실시간 보안 알림**: EventBridge를 통한 중요 보안 이벤트 감지
- **CloudWatch Logs 통합**: 실시간 로그 스트리밍 및 메트릭
- **자동 수명 주기 관리**: S3 Glacier 전환 및 자동 만료 정책

## 아키텍처 구성

```
CloudTrail (Multi-Region)
    ├── S3 Bucket (CloudTrail Logs) - KMS 암호화, Glacier 전환
    ├── CloudWatch Logs - 7일 보존
    ├── Athena Workspace
    │   ├── Glue Database & Table
    │   ├── S3 Bucket (Query Results)
    │   └── Named Queries (보안 분석)
    └── Security Monitoring
        ├── EventBridge Rules
        └── SNS Topic (보안 알림)
```

## 사용된 모듈

| 모듈 | 버전 | 용도 |
|------|------|------|
| `s3-bucket` | v1.0.0 | CloudTrail 로그 저장 버킷 |
| `s3-bucket` | v1.0.0 | Athena 쿼리 결과 저장 버킷 |

## 리소스 구성

### CloudTrail Trail
- **이름**: `central-cloudtrail`
- **타입**: Multi-region trail
- **로그 파일 검증**: 활성화
- **전역 서비스 이벤트**: 활성화 (IAM, STS 등)
- **암호화**: KMS (고객 관리형 키)

### S3 버킷

#### CloudTrail 로그 버킷
```hcl
module "cloudtrail_logs_bucket"
  - 이름: cloudtrail-logs-{account-id}
  - 암호화: KMS (aws_kms_key.cloudtrail)
  - 버전 관리: 활성화
  - 수명 주기:
    * 30일 → Glacier 전환
    * 90일 → 만료 (기본값, 변경 가능)
    * 미완료 업로드 7일 후 중단
  - 버킷 정책: CloudTrail 전용 쓰기 권한
```

#### Athena 쿼리 결과 버킷
```hcl
module "athena_results_bucket"
  - 이름: athena-query-results-{account-id}
  - 암호화: AES256 (Athena 제한사항)
  - 버전 관리: 비활성화
  - 수명 주기:
    * 7일 → 자동 삭제
    * 미완료 업로드 3일 후 중단
  - 용도: Athena 임시 쿼리 결과 저장
```

### KMS 암호화 키
```hcl
aws_kms_key.cloudtrail
  - 설명: CloudTrail logs encryption
  - 키 로테이션: 활성화
  - 삭제 대기 기간: 30일
  - 별칭: alias/cloudtrail-logs
  - 정책: CloudTrail, CloudWatch Logs 서비스 접근 권한
```

### Athena 분석 환경

#### Glue 카탈로그
- **데이터베이스**: `cloudtrail_logs`
- **테이블**: `cloudtrail_logs` (파티션: region, date)
- **파티션 프로젝션**: 자동 파티션 검색 (2020/01/01 ~ 현재)

#### Athena Workgroup
- **이름**: `cloudtrail-analysis`
- **쿼리 결과 위치**: s3://athena-query-results-{account-id}/query-results/
- **CloudWatch 메트릭**: 활성화

#### 사전 정의 Named Queries
1. **unauthorized-api-calls**: 최근 7일 무단 API 호출 (UnauthorizedOperation, AccessDenied)
2. **root-account-usage**: 최근 30일 루트 계정 사용 내역
3. **console-login-failures**: 최근 7일 콘솔 로그인 실패
4. **iam-policy-changes**: 최근 30일 IAM 정책 변경 사항

### 보안 모니터링

#### EventBridge Rules
- **Root Account Usage**: 루트 계정 사용 즉시 알림
- 향후 추가 가능: 무단 API 호출, IAM 정책 변경, 보안 그룹 변경 등

#### SNS Topic
- **이름**: `cloudtrail-security-alerts`
- **암호화**: KMS (cloudtrail 키)
- **구독**: 이메일 알림 (선택 사항)

## 배포 방법

### 1. 사전 준비

```bash
# AWS 계정 ID 확인
aws sts get-caller-identity --query Account --output text

# 변수 파일 생성
cp terraform.tfvars.example terraform.tfvars
```

### 2. terraform.tfvars 설정

```hcl
# 필수 변수
aws_account_id = "123456789012"  # 실제 AWS 계정 ID
environment    = "prod"

# 선택 변수
cloudtrail_name     = "central-cloudtrail"
log_retention_days  = 90  # S3 로그 보존 기간

# Athena 활성화 (권장)
enable_athena = true

# 보안 알림 설정
enable_security_alerts = true
alert_email            = "security-team@example.com"

# 데이터 이벤트 로깅 (비용 발생 주의!)
enable_s3_data_events     = false  # S3 읽기/쓰기 이벤트
enable_lambda_data_events = false  # Lambda 실행 이벤트

# 거버넌스 태그
team        = "platform-team"
owner       = "platform@example.com"
cost_center = "infrastructure"
```

### 3. 배포 실행

```bash
# 작업 디렉토리 이동
cd terraform/environments/prod/cloudtrail

# Terraform 초기화
terraform init

# 구성 검증
terraform validate
terraform fmt

# 변경 사항 확인
terraform plan

# 배포 실행
terraform apply
```

### 4. 배포 확인

```bash
# CloudTrail 상태 확인
aws cloudtrail get-trail-status --name central-cloudtrail

# S3 버킷 확인
aws s3 ls | grep cloudtrail

# Athena 워크그룹 확인
aws athena list-work-groups

# SNS 토픽 확인
aws sns list-topics | grep cloudtrail
```

## 운영 가이드

### Athena를 통한 로그 분석

#### 1. AWS 콘솔에서 쿼리 실행

```
AWS Console → Athena → Query Editor
→ Workgroup: cloudtrail-analysis
→ Database: cloudtrail_logs
→ Saved Queries 선택 또는 직접 쿼리 작성
```

#### 2. 커스텀 쿼리 예제

**특정 사용자의 활동 조회**:
```sql
SELECT
  eventtime,
  eventname,
  awsregion,
  sourceipaddress,
  useragent
FROM cloudtrail_logs
WHERE useridentity.principalid = 'AIDAXXXXXXXXXX'
  AND date >= date_format(current_date - interval '7' day, '%Y/%m/%d')
ORDER BY eventtime DESC
LIMIT 100;
```

**특정 서비스의 모든 이벤트**:
```sql
SELECT
  eventtime,
  eventname,
  useridentity.arn,
  requestparameters,
  responseelements
FROM cloudtrail_logs
WHERE eventsource = 'ec2.amazonaws.com'
  AND date >= date_format(current_date - interval '1' day, '%Y/%m/%d')
ORDER BY eventtime DESC;
```

**보안 그룹 변경 추적**:
```sql
SELECT
  eventtime,
  eventname,
  useridentity.arn,
  requestparameters
FROM cloudtrail_logs
WHERE eventname IN (
  'AuthorizeSecurityGroupIngress',
  'AuthorizeSecurityGroupEgress',
  'RevokeSecurityGroupIngress',
  'RevokeSecurityGroupEgress',
  'CreateSecurityGroup',
  'DeleteSecurityGroup'
)
  AND date >= date_format(current_date - interval '7' day, '%Y/%m/%d')
ORDER BY eventtime DESC;
```

**EC2 인스턴스 생성/삭제 이벤트**:
```sql
SELECT
  eventtime,
  eventname,
  useridentity.arn,
  requestparameters,
  responseelements
FROM cloudtrail_logs
WHERE eventname IN ('RunInstances', 'TerminateInstances')
  AND date >= date_format(current_date - interval '30' day, '%Y/%m/%d')
ORDER BY eventtime DESC;
```

### 보안 알림 관리

#### SNS 구독 확인
```bash
# 구독 목록 확인
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:ap-northeast-2:ACCOUNT_ID:cloudtrail-security-alerts

# 이메일 구독 추가 (terraform.tfvars에서도 설정 가능)
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-northeast-2:ACCOUNT_ID:cloudtrail-security-alerts \
  --protocol email \
  --notification-endpoint security@example.com
```

#### EventBridge Rule 추가 예제
```hcl
# monitoring.tf에 추가
resource "aws_cloudwatch_event_rule" "unauthorized-api-calls" {
  count       = var.enable_security_alerts ? 1 : 0
  name        = "${var.cloudtrail_name}-unauthorized-api-calls"
  description = "Alert on unauthorized API calls"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      errorCode = ["UnauthorizedOperation", "AccessDenied"]
    }
  })
}

resource "aws_cloudwatch_event_target" "unauthorized-api-calls" {
  count     = var.enable_security_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.unauthorized-api-calls[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security-alerts[0].arn
}
```

### CloudWatch Logs 조회

```bash
# 로그 그룹 확인
aws logs describe-log-groups --log-group-name-prefix /aws/cloudtrail

# 최근 로그 스트림 조회
aws logs describe-log-streams \
  --log-group-name /aws/cloudtrail/central-cloudtrail \
  --order-by LastEventTime \
  --descending \
  --max-items 10

# 로그 이벤트 조회
aws logs tail /aws/cloudtrail/central-cloudtrail --follow
```

### 비용 관리

#### 현재 설정 비용 추정 (ap-northeast-2 기준)
- **CloudTrail**: $2.00/월 (첫 번째 trail 무료)
- **S3 스토리지**: ~$0.025/GB/월 (Standard) → $0.0125/GB/월 (Glacier)
- **CloudWatch Logs**: ~$0.76/GB (수집) + $0.033/GB/월 (보관)
- **Athena**: $5.00/TB (스캔 데이터 기준)

#### 비용 절감 팁
```hcl
# 1. CloudWatch Logs 보존 기간 단축 (현재: 7일)
# cloudtrail.tf 수정
retention_in_days = 3  # 또는 1일

# 2. Athena 쿼리 결과 보존 기간 단축 (현재: 7일)
# s3.tf 수정
expiration_days = 3

# 3. CloudTrail 로그 보존 기간 조정 (현재: 90일)
# terraform.tfvars 수정
log_retention_days = 30  # 30일로 단축

# 4. 데이터 이벤트 로깅 비활성화 유지 (기본값)
enable_s3_data_events     = false
enable_lambda_data_events = false
```

### 로그 보존 정책 변경

```hcl
# terraform.tfvars 수정
log_retention_days = 365  # 1년 보존

# 또는 s3.tf에서 수명 주기 직접 수정
lifecycle_rules = [
  {
    id      = "cloudtrail-log-retention"
    enabled = true
    prefix  = ""

    transition_to_ia_days      = 30   # 30일 후 IA
    transition_to_glacier_days = 90   # 90일 후 Glacier
    expiration_days            = 2555 # 7년 보존 (규정 준수)

    abort_incomplete_upload_days = 7
  }
]
```

## 보안 및 규정 준수

### 거버넌스 준수 사항

✅ **필수 태그**: `common-tags` 모듈 통해 자동 적용
- Owner, CostCenter, Environment, Service, Team, Project, DataClass

✅ **KMS 암호화**: 고객 관리형 KMS 키 사용
- CloudTrail 로그: KMS 암호화 필수
- Athena 결과: AES256 (Athena 제한사항)

✅ **명명 규칙**: kebab-case 준수
- 리소스: `cloudtrail-logs-{account-id}`
- 변수: `aws_account_id`, `log_retention_days`

✅ **버킷 정책**: 최소 권한 원칙
- CloudTrail 서비스만 쓰기 권한
- 암호화되지 않은 객체 업로드 거부
- HTTPS 전송 강제

### 보안 모범 사례

#### 1. 로그 파일 무결성 검증
```bash
# 로그 파일 다이제스트 검증
aws cloudtrail validate-logs \
  --trail-arn arn:aws:cloudtrail:ap-northeast-2:ACCOUNT_ID:trail/central-cloudtrail \
  --start-time 2024-11-20T00:00:00Z
```

#### 2. 정기 보안 감사
```sql
-- Athena에서 주간 보안 리포트 생성
WITH security_events AS (
  SELECT
    DATE(from_iso8601_timestamp(eventtime)) as event_date,
    eventname,
    COUNT(*) as event_count
  FROM cloudtrail_logs
  WHERE date >= date_format(current_date - interval '7' day, '%Y/%m/%d')
    AND (
      errorcode IS NOT NULL
      OR eventname LIKE '%Delete%'
      OR eventname LIKE '%Terminate%'
      OR useridentity.type = 'Root'
    )
  GROUP BY 1, 2
)
SELECT * FROM security_events
ORDER BY event_date DESC, event_count DESC;
```

#### 3. S3 버킷 액세스 모니터링
```bash
# S3 버킷 정책 확인
aws s3api get-bucket-policy \
  --bucket cloudtrail-logs-ACCOUNT_ID

# 퍼블릭 액세스 차단 확인
aws s3api get-public-access-block \
  --bucket cloudtrail-logs-ACCOUNT_ID
```

## 문제 해결

### CloudTrail 로그가 S3에 기록되지 않음

**원인 1**: 버킷 정책 문제
```bash
# 버킷 정책 확인
aws s3api get-bucket-policy \
  --bucket cloudtrail-logs-ACCOUNT_ID \
  --query Policy --output text | jq .

# 해결: terraform apply로 버킷 정책 재적용
terraform apply -target=aws_s3_bucket_policy.cloudtrail
```

**원인 2**: KMS 키 권한 문제
```bash
# KMS 키 정책 확인
aws kms get-key-policy \
  --key-id alias/cloudtrail-logs \
  --policy-name default

# 해결: terraform apply로 KMS 정책 재적용
terraform apply -target=aws_kms_key.cloudtrail
```

**원인 3**: CloudTrail 비활성화
```bash
# CloudTrail 상태 확인
aws cloudtrail get-trail-status --name central-cloudtrail

# IsLogging이 false면 활성화
aws cloudtrail start-logging --name central-cloudtrail
```

### Athena 쿼리 실패

**오류**: "HIVE_PARTITION_SCHEMA_MISMATCH"
```sql
-- 해결: 파티션 메타데이터 수정
MSCK REPAIR TABLE cloudtrail_logs;
```

**오류**: "Access Denied" (쿼리 결과 버킷)
```bash
# Athena 결과 버킷 권한 확인
aws s3api get-bucket-policy \
  --bucket athena-query-results-ACCOUNT_ID

# IAM 사용자/역할에 S3 쓰기 권한 추가 필요
```

**쿼리 성능 개선**:
```sql
-- 파티션 필터 반드시 사용
WHERE date >= '2024/11/20'  -- 필수!
  AND region = 'ap-northeast-2'

-- 스캔 데이터 최소화
SELECT eventtime, eventname  -- 필요한 컬럼만 선택
FROM cloudtrail_logs
WHERE ...
```

### EventBridge 알림이 오지 않음

```bash
# EventBridge Rule 상태 확인
aws events describe-rule --name central-cloudtrail-root-account-usage

# Rule이 ENABLED 상태인지 확인
# State가 DISABLED면 활성화
aws events enable-rule --name central-cloudtrail-root-account-usage

# SNS 구독 확인
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:ap-northeast-2:ACCOUNT_ID:cloudtrail-security-alerts

# 이메일 구독 상태가 "PendingConfirmation"이면 이메일에서 확인 필요
```

## 제한사항

### CloudTrail
- **관리 이벤트**: 무료 (첫 번째 trail)
- **데이터 이벤트**: 추가 비용 발생 (10만 이벤트당 $0.10)
- **Insights 이벤트**: 지원하지 않음 (현재 구성)

### Athena
- **쿼리 결과 암호화**: KMS 미지원 (AES256만 가능)
- **파티션**: Region과 Date만 사용 (추가 파티션 불가)
- **최대 쿼리 실행 시간**: 30분

### S3 수명 주기
- **최소 전환 기간**:
  - Standard → STANDARD_IA: 30일
  - Standard → GLACIER: 90일 (현재 설정)

## 참고 자료

### AWS 공식 문서
- [CloudTrail User Guide](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/)
- [Querying CloudTrail Logs with Athena](https://docs.aws.amazon.com/athena/latest/ug/cloudtrail-logs.html)
- [CloudTrail Log File Examples](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-log-file-examples.html)

### 내부 문서
- [거버넌스 표준](../../../docs/governance/)
- [보안 가이드](../../../docs/guides/SECURITY.md)
- [S3 Bucket 모듈](../../../modules/s3-bucket/README.md)

## 변경 이력

자세한 변경 사항은 [CHANGELOG.md](./CHANGELOG.md)를 참조하세요.

## 작성자

Platform Team (platform@example.com)

---

**중요 알림**:
- 루트 계정 사용은 CloudTrail에 기록되며 즉시 알림이 전송됩니다
- S3/Lambda 데이터 이벤트 로깅은 대량 비용이 발생할 수 있으므로 신중히 활성화하세요
- 정기적으로 Athena를 통해 보안 감사를 수행하세요
