# Central Logging System - Production Environment

**환경**: Production
**목적**: 중앙 집중식 로그 수집 및 관리
**관리**: Platform Team
**버전**: v1.0.0

## 개요

Production 환경의 모든 서비스 로그를 중앙 집중식으로 관리하는 CloudWatch Log Groups 스택입니다. KMS 암호화와 표준화된 보관 정책을 적용하여 로그 데이터를 안전하게 관리합니다.

### 현재 관리 대상

- **ECS Services**: Atlantis (application, errors)
- **Lambda Functions**: Secrets Manager Rotation
- **Future Services**: API Server, Auth Service (준비 완료)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Central Logging System                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ECS Service Logs                 Lambda Function Logs       │
│  ┌──────────────────┐            ┌──────────────────┐       │
│  │ Atlantis         │            │ Secrets Rotation │       │
│  │ ├─ application   │            │ └─ application   │       │
│  │ └─ errors (Sentry)│           │                  │       │
│  └──────────────────┘            └──────────────────┘       │
│                                                               │
│  All Logs → KMS Encrypted (CloudWatch Logs Key)             │
│  All Logs → Standard Retention Policies                      │
│  All Logs → Centralized Access Control                       │
└─────────────────────────────────────────────────────────────┘
```

## Module Usage

이 스택은 `cloudwatch-log-group` 모듈을 사용하여 3개의 로그 그룹을 관리합니다.

### Module: cloudwatch-log-group

**버전**: v1.0.0
**경로**: `../../../modules/cloudwatch-log-group`

**사용 예시**:

```hcl
module "atlantis_application_logs" {
  source = "../../../modules/cloudwatch-log-group"

  name              = "/aws/ecs/atlantis/application"
  retention_in_days = 14
  kms_key_id        = local.kms_key_arn
  log_type          = "application"

  # Required tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = var.data_class
}
```

## Log Groups

### 1. Atlantis Application Logs

**Name**: `/aws/ecs/atlantis/application`
**Type**: `application`
**Retention**: 14 days
**용도**: Atlantis 서버의 일반 애플리케이션 로그

일반적인 Atlantis 작업 로그 (PR 처리, Terraform 실행 등)를 수집합니다.

### 2. Atlantis Error Logs

**Name**: `/aws/ecs/atlantis/errors`
**Type**: `errors`
**Retention**: 90 days
**용도**: Atlantis 에러 로그 (Sentry 연동 준비)

에러 레벨 로그만 수집하며, 향후 Sentry와 연동하여 실시간 에러 모니터링을 제공할 예정입니다.

**Future Features**:
- Sentry integration via Subscription Filter
- Error rate metric (CloudWatch Custom Metrics)
- Real-time error alerting

### 3. Secrets Manager Rotation Lambda

**Name**: `/aws/lambda/secrets-manager-rotation`
**Type**: `application`
**Retention**: 14 days
**용도**: Secrets Manager Rotation Lambda 로그

AWS Secrets Manager의 자동 시크릿 로테이션 Lambda 함수 로그를 수집합니다.

## KMS Encryption

모든 로그 그룹은 KMS 암호화를 사용합니다.

**KMS Key Source**: Terraform Remote State (`kms` stack)

```hcl
data "terraform_remote_state" "kms" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "kms/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  kms_key_arn = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn
}
```

**Key Details**:
- **Purpose**: CloudWatch Logs 암호화 전용
- **Rotation**: 자동 키 로테이션 활성화
- **Access**: CloudWatch Logs 서비스 및 승인된 IAM 역할만 접근 가능

## Retention Policies

| Log Type | Retention | Rationale |
|----------|-----------|-----------|
| Application | 14 days | 일반 운영 로그, 단기 디버깅 용도 |
| Errors | 90 days | 에러 패턴 분석 및 장기 트렌드 파악 |
| Audit | 365 days | 규정 준수 및 감사 요구사항 |

## Future Service Log Groups (Prepared)

다음 서비스 로그 그룹은 코드에 준비되어 있으며, 서비스 배포 시 주석 해제하여 사용합니다:

### API Server Logs

```hcl
# /aws/ecs/api-server/application (14 days)
# /aws/ecs/api-server/errors (90 days, Sentry ready)
# /aws/ecs/api-server/llm (60 days, Langfuse ready)
```

**Activation**: `main.tf`에서 주석 해제 후 `terraform apply`

## Outputs

### Individual Log Group Details

```hcl
output "atlantis_application_log_group" {
  value = {
    name              = "/aws/ecs/atlantis/application"
    arn               = "arn:aws:logs:..."
    retention_in_days = 14
  }
}

output "atlantis_error_log_group" {
  value = {
    name              = "/aws/ecs/atlantis/errors"
    arn               = "arn:aws:logs:..."
    retention_in_days = 90
  }
}

output "secrets_rotation_log_group" {
  value = {
    name              = "/aws/lambda/secrets-manager-rotation"
    arn               = "arn:aws:logs:..."
    retention_in_days = 14
  }
}
```

### Summary Output

```hcl
output "log_groups_summary" {
  value = {
    total_groups = 3
    groups = [
      {
        name      = "/aws/ecs/atlantis/application"
        type      = "application"
        retention = 14
      },
      {
        name      = "/aws/ecs/atlantis/errors"
        type      = "errors"
        retention = 90
      },
      {
        name      = "/aws/lambda/secrets-manager-rotation"
        type      = "application"
        retention = 14
      }
    ]
  }
}
```

### KMS Key Information

```hcl
output "kms_key_used" {
  value = {
    arn   = "arn:aws:kms:ap-northeast-2:..."
    alias = "alias/cloudwatch-logs"
  }
}
```

## Variables

### Required Variables

| Name | Description | Type | Default | Example |
|------|-------------|------|---------|---------|
| `environment` | 환경 이름 | `string` | `"prod"` | `"prod"` |
| `service_name` | 서비스 이름 | `string` | `"logging"` | `"logging"` |
| `team` | 담당 팀 | `string` | `"platform-team"` | `"platform-team"` |
| `owner` | 리소스 소유자 | `string` | `"fbtkdals2@naver.com"` | Email 형식 |
| `cost_center` | 비용 센터 | `string` | `"infrastructure"` | `"infrastructure"` |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `aws_region` | AWS 리전 | `string` | `"ap-northeast-2"` |
| `terraform_state_bucket` | Terraform State S3 버킷 | `string` | `"terraform-state-bucket"` |
| `project` | 프로젝트 이름 | `string` | `"infrastructure"` |
| `data_class` | 데이터 분류 | `string` | `"confidential"` |

## Deployment

### Prerequisites

1. **KMS Stack 배포 완료**: `terraform/environments/prod/kms` 스택이 먼저 배포되어야 합니다.
2. **Terraform State Backend**: S3 backend가 구성되어 있어야 합니다.

### Deployment Steps

```bash
# 1. 디렉토리 이동
cd terraform/environments/prod/logging

# 2. 초기화
terraform init

# 3. 포맷 확인
terraform fmt

# 4. 검증
terraform validate

# 5. 계획 확인
terraform plan

# 6. 배포 (CI/CD에서 자동 실행)
terraform apply
```

### Verification

배포 후 로그 그룹 생성 확인:

```bash
# CloudWatch Log Groups 확인
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/ecs/atlantis" \
  --region ap-northeast-2

# KMS 암호화 확인
aws logs describe-log-groups \
  --log-group-name "/aws/ecs/atlantis/application" \
  --query 'logGroups[0].kmsKeyId' \
  --region ap-northeast-2

# Retention 정책 확인
aws logs describe-log-groups \
  --log-group-name "/aws/ecs/atlantis/application" \
  --query 'logGroups[0].retentionInDays' \
  --region ap-northeast-2
```

## Monitoring

### CloudWatch Insights Queries

**Atlantis 에러 로그 조회**:
```
fields @timestamp, @message
| filter @logStream like /errors/
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

**Lambda 실행 실패 조회**:
```
fields @timestamp, @message
| filter @message like /ERROR/
| filter @message like /rotation/
| sort @timestamp desc
| limit 50
```

### Metrics and Alarms

현재 설정된 메트릭:

- **Atlantis Error Rate**: `enable_error_rate_metric = true`로 설정되어 있으나 Lambda 기반 메트릭 필터는 향후 활성화 예정

향후 추가 예정:
- Error rate threshold alarms
- Log ingestion rate monitoring
- Cost anomaly detection

## Tagging Strategy

모든 로그 그룹은 다음 태그를 자동으로 적용받습니다:

### Common Tags (from module)

| Tag | Value | Description |
|-----|-------|-------------|
| `Environment` | `prod` | 환경 구분 |
| `Service` | `logging` | 서비스 이름 |
| `Team` | `platform-team` | 담당 팀 |
| `Owner` | `fbtkdals2@naver.com` | 리소스 소유자 |
| `CostCenter` | `infrastructure` | 비용 센터 |
| `ManagedBy` | `Terraform` | 관리 방법 |
| `Project` | `infrastructure` | 프로젝트 |
| `DataClass` | `confidential` | 데이터 분류 |

### Log-Specific Tags

| Tag | Example Value | Description |
|-----|---------------|-------------|
| `Name` | `/aws/ecs/atlantis/application` | 로그 그룹 이름 |
| `LogType` | `application` | 로그 타입 |
| `RetentionDays` | `14` | 보관 기간 |
| `KMSEncrypted` | `true` | KMS 암호화 여부 |
| `ExportToS3` | `false` | S3 내보내기 상태 |
| `SentrySync` | `pending` | Sentry 연동 상태 |
| `Component` | `log-group` | 컴포넌트 타입 |

## Cost Optimization

### Current Monthly Cost Estimate

| Resource | Estimated Cost | Notes |
|----------|---------------|-------|
| Log Ingestion (10 GB/month) | ~$5 | CloudWatch Logs 수집 비용 |
| Log Storage (14-90 days) | ~$3 | 보관 비용 |
| KMS Encryption | ~$1 | API 요청 비용 |
| **Total** | **~$9/month** | 3개 로그 그룹 기준 |

### Cost Optimization Strategies

1. **Retention 정책 최적화**:
   - Application logs: 14일 (단기 디버깅 충분)
   - Error logs: 90일 (패턴 분석용)

2. **S3 Export 비활성화**:
   - 현재 필요하지 않으므로 비활성화
   - 필요 시 선택적 활성화

3. **Log Filtering**:
   - 애플리케이션 레벨에서 불필요한 로그 제거
   - 구조화된 로그 포맷 사용 (JSON)

4. **Future Optimization**:
   - S3 archival with lifecycle policies
   - CloudWatch Logs Insights를 통한 쿼리 최적화

## Security

### Encryption

- **At Rest**: KMS customer-managed key 사용
- **In Transit**: TLS 1.2+ 강제 적용
- **Key Rotation**: 자동 키 로테이션 활성화

### Access Control

로그 그룹 접근은 IAM 정책으로 제어됩니다:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ],
      "Resource": "arn:aws:logs:ap-northeast-2:*:log-group:/aws/ecs/atlantis/*"
    }
  ]
}
```

### Compliance

- **데이터 분류**: `confidential` (모든 로그 그룹)
- **보관 정책**: 로그 타입별 차등 적용
- **암호화**: 모든 로그 그룹 KMS 암호화 필수

## Troubleshooting

### Common Issues

**1. Log Group Already Exists Error**

```bash
# 원인: Log group이 이미 존재하는 경우
# 해결: terraform import로 기존 리소스 가져오기

terraform import module.atlantis_application_logs.aws_cloudwatch_log_group.this \
  /aws/ecs/atlantis/application
```

**2. KMS Permission Denied**

```bash
# 원인: CloudWatch Logs 서비스가 KMS 키에 접근할 수 없음
# 해결: KMS 키 정책에서 CloudWatch Logs 서비스 권한 확인

aws kms get-key-policy \
  --key-id alias/cloudwatch-logs \
  --policy-name default \
  --region ap-northeast-2
```

**3. Remote State Access Error**

```bash
# 원인: KMS remote state를 찾을 수 없음
# 해결: KMS 스택이 먼저 배포되었는지 확인

cd ../kms
terraform output cloudwatch_logs_key_arn
```

### Validation

배포 전 governance 검증:

```bash
# Tags 검증
./scripts/validators/check-tags.sh

# Encryption 검증
./scripts/validators/check-encryption.sh

# Naming convention 검증
./scripts/validators/check-naming.sh

# Security scan
./scripts/validators/check-tfsec.sh
```

## Future Enhancements

### Phase 2: Sentry Integration (Q1 2025)

- [ ] Lambda function for error log transformation
- [ ] Subscription filter activation
- [ ] Sentry API integration
- [ ] Error alerting setup

### Phase 3: Langfuse Integration (Q2 2025)

- [ ] Lambda function for LLM log transformation
- [ ] Subscription filter for LLM logs
- [ ] Langfuse API integration
- [ ] Token usage tracking

### Phase 4: S3 Archival (Q2 2025)

- [ ] S3 bucket for long-term log archival
- [ ] Lifecycle policies (Standard → IA → Glacier)
- [ ] Automated export scheduling
- [ ] Cost optimization

### Phase 5: Log Analytics (Q3 2025)

- [ ] Centralized log analytics dashboard
- [ ] Automated anomaly detection
- [ ] Cost allocation by service
- [ ] Performance insights

## Related Documentation

- [CloudWatch Log Group Module](../../../modules/cloudwatch-log-group/README.md)
- [Logging System Design](../../../claudedocs/IN-116-logging-system-design.md)
- [Logging Naming Convention](../../../docs/LOGGING_NAMING_CONVENTION.md)
- [Tagging Standards](../../../docs/TAGGING_STANDARDS.md)
- [KMS Key Management](../../../docs/KMS_KEY_MANAGEMENT.md)

## Support

**Team**: Platform Team
**Owner**: fbtkdals2@naver.com
**Slack**: #platform-team
**Jira**: [IN-116](https://jira.example.com/browse/IN-116)

---

**Last Updated**: 2025-11-24
**Version**: v1.0.0
**Terraform Version**: >= 1.5.0
**AWS Provider Version**: >= 5.0
