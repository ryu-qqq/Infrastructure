# S3 Bucket 모듈

거버넌스 규정을 준수하는 표준화된 AWS S3 버킷 생성 모듈입니다. 암호화, 버전 관리, 수명 주기, CORS, 정적 웹사이트 호스팅, Object Lock, CloudWatch 알람을 포함한 종합적인 S3 버킷 관리 기능을 제공합니다.

## 주요 기능

- **필수 거버넌스 준수**: 필수 태그, KMS 암호화, 명명 규칙 자동 적용
- **보안 강화**: 기본 퍼블릭 액세스 차단, 서버 측 암호화 (KMS/AES256)
- **버전 관리**: 객체 버전 관리 및 Object Lock (WORM) 지원
- **수명 주기 관리**: 다단계 스토리지 클래스 전환 및 만료 정책
- **액세스 로깅**: S3 액세스 로그 저장 기능
- **CORS 설정**: 크로스 오리진 리소스 공유 규칙 구성
- **정적 웹사이트**: S3 정적 웹사이트 호스팅 지원
- **모니터링**: CloudWatch 알람 및 Request Metrics 통합
- **표준화된 태그**: common-tags 모듈 통합으로 일관된 태그 관리

## 사용 예제

### 기본 S3 버킷 (KMS 암호화)

```hcl
module "app_data_bucket" {
  source = "../../modules/s3-bucket"

  bucket_name = "prod-app-data"

  # 필수 태그
  environment = "prod"
  service_name = "api-server"
  team = "platform-team"
  owner = "platform@example.com"
  cost_center = "engineering"

  # KMS 암호화 (권장)
  kms_key_id = aws_kms_key.s3.arn

  # 버전 관리 활성화
  versioning_enabled = true
}
```

### 수명 주기 정책이 있는 로그 버킷

```hcl
module "logs_bucket" {
  source = "../../modules/s3-bucket"

  bucket_name = "prod-application-logs"

  environment = "prod"
  service_name = "logging"
  team = "platform-team"
  owner = "platform@example.com"
  cost_center = "engineering"
  data_class = "internal"

  kms_key_id = aws_kms_key.logs.arn
  versioning_enabled = true

  # 수명 주기 규칙
  lifecycle_rules = [
    {
      id      = "archive-old-logs"
      enabled = true
      prefix  = "app-logs/"

      transition_to_ia_days      = 30   # 30일 후 IA로 전환
      transition_to_glacier_days = 90   # 90일 후 Glacier로 전환
      expiration_days            = 365  # 1년 후 삭제

      noncurrent_expiration_days   = 30  # 비현재 버전 30일 후 삭제
      abort_incomplete_upload_days = 7   # 미완료 멀티파트 업로드 7일 후 중단
    }
  ]
}
```

### CORS가 활성화된 정적 웹사이트

```hcl
module "static_website" {
  source = "../../modules/s3-bucket"

  bucket_name = "prod-company-website"

  environment = "prod"
  service_name = "website"
  team = "frontend-team"
  owner = "frontend@example.com"
  cost_center = "marketing"
  data_class = "public"

  kms_key_id = aws_kms_key.website.arn

  # 정적 웹사이트 호스팅
  enable_static_website = true
  website_index_document = "index.html"
  website_error_document = "404.html"

  # CORS 설정
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["https://example.com", "https://www.example.com"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3600
    }
  ]

  # 퍼블릭 읽기 액세스 허용 (정적 웹사이트용)
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
```

### CloudWatch 알람이 있는 모니터링 버킷

```hcl
module "monitored_bucket" {
  source = "../../modules/s3-bucket"

  bucket_name = "prod-analytics-data"

  environment = "prod"
  service_name = "analytics"
  team = "data-team"
  owner = "data@example.com"
  cost_center = "engineering"

  kms_key_id = aws_kms_key.analytics.arn
  versioning_enabled = true

  # CloudWatch 알람 활성화
  enable_cloudwatch_alarms = true
  alarm_bucket_size_threshold = 536870912000  # 500GB
  alarm_object_count_threshold = 5000000       # 500만 객체
  alarm_actions = [aws_sns_topic.alerts.arn]
  alarm_period = 86400  # 24시간

  # Request Metrics 활성화
  enable_request_metrics = true
  request_metrics_filter_prefix = "data/"
}
```

### Object Lock이 있는 규정 준수 버킷

```hcl
module "compliance_bucket" {
  source = "../../modules/s3-bucket"

  bucket_name = "prod-financial-records"

  environment = "prod"
  service_name = "finance"
  team = "finance-team"
  owner = "finance@example.com"
  cost_center = "finance"
  data_class = "confidential"

  kms_key_id = aws_kms_key.finance.arn
  versioning_enabled = true  # Object Lock에 필수

  # Object Lock (WORM - Write Once Read Many)
  enable_object_lock = true
  object_lock_mode = "COMPLIANCE"
  object_lock_retention_years = 7  # 7년 보존

  # 액세스 로깅
  logging_enabled = true
  logging_target_bucket = module.audit_logs_bucket.bucket_id
  logging_target_prefix = "s3-access-logs/financial-records/"
}
```

### 완전한 엔터프라이즈 설정

```hcl
module "enterprise_bucket" {
  source = "../../modules/s3-bucket"

  bucket_name = "prod-enterprise-storage"

  # 필수 태그
  environment = "prod"
  service_name = "storage"
  team = "platform-team"
  owner = "platform@example.com"
  cost_center = "engineering"
  project = "enterprise-storage"
  data_class = "confidential"

  # 추가 태그
  additional_tags = {
    Compliance = "soc2"
    Backup     = "enabled"
  }

  # 암호화 및 버전 관리
  kms_key_id = aws_kms_key.enterprise.arn
  versioning_enabled = true

  # 수명 주기 정책
  lifecycle_rules = [
    {
      id      = "intelligent-tiering"
      enabled = true

      transition_to_ia_days      = 90
      transition_to_glacier_days = 180
      expiration_days            = 2555  # 7년

      noncurrent_expiration_days   = 90
      abort_incomplete_upload_days = 7
    }
  ]

  # 액세스 로깅
  logging_enabled = true
  logging_target_bucket = module.audit_logs.bucket_id
  logging_target_prefix = "s3-access/enterprise-storage/"

  # 모니터링 및 알람
  enable_cloudwatch_alarms = true
  alarm_bucket_size_threshold = 1099511627776  # 1TB
  alarm_object_count_threshold = 10000000       # 1000만 객체
  alarm_actions = [
    aws_sns_topic.critical_alerts.arn,
    aws_sns_topic.ops_team.arn
  ]

  enable_request_metrics = true
}
```

## 입력 변수

### 필수 변수

| 이름 | 타입 | 설명 | 검증 규칙 |
|------|------|------|----------|
| `bucket_name` | string | S3 버킷 이름 | kebab-case, 소문자 영숫자와 하이픈만 허용 |
| `environment` | string | 환경 (dev, staging, prod) | dev, staging, prod 중 하나 |
| `service_name` | string | 서비스 이름 | kebab-case |
| `team` | string | 담당 팀 | kebab-case |
| `owner` | string | 리소스 소유자 이메일 또는 식별자 | 유효한 이메일 또는 kebab-case |
| `cost_center` | string | 비용 센터 | kebab-case |

### 선택 변수 (태그)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `project` | string | `"infrastructure"` | 프로젝트 이름 |
| `data_class` | string | `"confidential"` | 데이터 분류 (confidential, internal, public) |
| `additional_tags` | map(string) | `{}` | 추가 태그 |

### 선택 변수 (S3 설정)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `kms_key_id` | string | `null` | KMS 키 ARN (거버넌스 준수에 권장) |
| `versioning_enabled` | bool | `true` | 버전 관리 활성화 |
| `force_destroy` | bool | `false` | 비어있지 않은 버킷 삭제 허용 (프로덕션에서 주의) |
| `block_public_acls` | bool | `true` | 퍼블릭 ACL 차단 |
| `block_public_policy` | bool | `true` | 퍼블릭 버킷 정책 차단 |
| `ignore_public_acls` | bool | `true` | 퍼블릭 ACL 무시 |
| `restrict_public_buckets` | bool | `true` | 퍼블릭 버킷 정책 제한 |

### 선택 변수 (로깅)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `logging_enabled` | bool | `false` | 액세스 로깅 활성화 |
| `logging_target_bucket` | string | `null` | 로그 저장 대상 버킷 (logging_enabled가 true일 때 필수) |
| `logging_target_prefix` | string | `"logs/"` | 로그 객체 접두사 |

### 선택 변수 (수명 주기)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `lifecycle_rules` | list(object) | `[]` | 수명 주기 규칙 목록 |

**수명 주기 규칙 객체 구조**:
```hcl
{
  id                           = string           # 규칙 ID
  enabled                      = bool             # 규칙 활성화 여부
  prefix                       = optional(string) # 객체 접두사 필터
  expiration_days              = optional(number) # 만료 기간 (일)
  transition_to_ia_days        = optional(number) # STANDARD_IA로 전환 (일)
  transition_to_glacier_days   = optional(number) # GLACIER로 전환 (일)
  noncurrent_expiration_days   = optional(number) # 비현재 버전 만료 (일)
  abort_incomplete_upload_days = optional(number) # 미완료 멀티파트 업로드 중단 (일)
}
```

### 선택 변수 (CORS)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `cors_rules` | list(object) | `[]` | CORS 규칙 목록 |

**CORS 규칙 객체 구조**:
```hcl
{
  allowed_headers = list(string)           # 허용된 헤더
  allowed_methods = list(string)           # 허용된 메서드 (GET, PUT, POST, DELETE, HEAD)
  allowed_origins = list(string)           # 허용된 오리진
  expose_headers  = optional(list(string)) # 노출할 헤더
  max_age_seconds = optional(number)       # 프리플라이트 요청 캐시 시간
}
```

### 선택 변수 (정적 웹사이트)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `enable_static_website` | bool | `false` | 정적 웹사이트 호스팅 활성화 |
| `website_index_document` | string | `"index.html"` | 인덱스 문서 |
| `website_error_document` | string | `"error.html"` | 에러 문서 |

### 선택 변수 (모니터링)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `enable_cloudwatch_alarms` | bool | `false` | CloudWatch 알람 활성화 |
| `alarm_bucket_size_threshold` | number | `107374182400` | 버킷 크기 임계값 (바이트, 기본 100GB) |
| `alarm_object_count_threshold` | number | `1000000` | 객체 수 임계값 (기본 100만) |
| `alarm_actions` | list(string) | `[]` | 알람 트리거 시 알림 SNS 토픽 ARN |
| `alarm_period` | number | `86400` | 알람 평가 기간 (초, 기본 24시간) |
| `enable_request_metrics` | bool | `false` | S3 Request Metrics 활성화 |
| `request_metrics_filter_prefix` | string | `""` | Request Metrics 접두사 필터 (비어있으면 전체 버킷) |

### 선택 변수 (Object Lock)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `enable_object_lock` | bool | `false` | Object Lock 활성화 (WORM 보호) |
| `object_lock_mode` | string | `"GOVERNANCE"` | Object Lock 모드 (GOVERNANCE 또는 COMPLIANCE) |
| `object_lock_retention_days` | number | `null` | 기본 보존 기간 (일) |
| `object_lock_retention_years` | number | `null` | 기본 보존 기간 (년) |

## 출력 값

### 버킷 정보

| 이름 | 설명 |
|------|------|
| `bucket_id` | 버킷 ID (이름) |
| `bucket_arn` | 버킷 ARN |
| `bucket_domain_name` | 버킷 도메인 이름 |
| `bucket_regional_domain_name` | 리전별 버킷 도메인 이름 |
| `bucket_region` | 버킷이 위치한 AWS 리전 |
| `bucket_tags` | 버킷에 적용된 모든 태그 |

### 정적 웹사이트

| 이름 | 설명 |
|------|------|
| `website_endpoint` | 웹사이트 엔드포인트 (enable_static_website가 true일 때) |
| `website_domain` | 웹사이트 도메인 (enable_static_website가 true일 때) |

### 모니터링

| 이름 | 설명 |
|------|------|
| `cloudwatch_alarm_bucket_size_arn` | 버킷 크기 CloudWatch 알람 ARN |
| `cloudwatch_alarm_object_count_arn` | 객체 수 CloudWatch 알람 ARN |
| `request_metrics_name` | S3 Request Metrics 설정 이름 |

### Object Lock

| 이름 | 설명 |
|------|------|
| `object_lock_enabled` | Object Lock 활성화 여부 |
| `object_lock_configuration` | Object Lock 설정 세부 정보 (mode, retention_days, retention_years) |

## 거버넌스 준수

이 모듈은 다음 거버넌스 규정을 자동으로 적용합니다:

### 필수 태그

`common-tags` 모듈을 통해 다음 필수 태그가 모든 리소스에 자동 적용됩니다:
- `Owner`: 리소스 소유자
- `CostCenter`: 비용 센터
- `Environment`: 환경 (dev/staging/prod)
- `Lifecycle`: 라이프사이클 상태
- `DataClass`: 데이터 분류 수준
- `Service`: 서비스 이름

### KMS 암호화

프로덕션 환경에서는 `kms_key_id`를 지정하여 고객 관리형 KMS 키로 암호화하는 것을 강력히 권장합니다. KMS 키를 지정하지 않으면 AES256 암호화가 사용됩니다.

### 명명 규칙

버킷 이름은 kebab-case를 따라야 하며, 소문자 영숫자와 하이픈만 사용 가능합니다.

### 퍼블릭 액세스 차단

기본적으로 모든 퍼블릭 액세스가 차단됩니다. 정적 웹사이트 호스팅 등 특정 사용 사례에서는 명시적으로 설정을 변경해야 합니다.

## 보안 모범 사례

### 암호화

```hcl
# KMS 암호화 사용 (권장)
kms_key_id = aws_kms_key.s3.arn

# KMS 키가 없으면 AES256이 기본값으로 사용됨
# 프로덕션 환경에서는 KMS 사용 필수
```

### 버전 관리

중요한 데이터의 경우 항상 버전 관리를 활성화하세요:
```hcl
versioning_enabled = true
```

### Object Lock (규정 준수)

법적 또는 규정 준수 요구 사항이 있는 경우 Object Lock을 사용하세요:
```hcl
enable_object_lock = true
object_lock_mode = "COMPLIANCE"  # 또는 "GOVERNANCE"
object_lock_retention_years = 7
```

### 액세스 로깅

모든 프로덕션 버킷에 대해 액세스 로깅을 활성화하세요:
```hcl
logging_enabled = true
logging_target_bucket = module.audit_logs.bucket_id
logging_target_prefix = "s3-access/my-bucket/"
```

### 퍼블릭 액세스

기본 설정을 유지하여 퍼블릭 액세스를 차단하세요. 퍼블릭 액세스가 필요한 경우에만 명시적으로 변경하세요.

## 수명 주기 관리 전략

### 로그 데이터 아카이빙

```hcl
lifecycle_rules = [
  {
    id      = "archive-logs"
    enabled = true
    prefix  = "logs/"

    transition_to_ia_days      = 30   # 30일 후 저비용 액세스
    transition_to_glacier_days = 90   # 90일 후 Glacier
    expiration_days            = 365  # 1년 후 삭제
  }
]
```

### 임시 데이터 정리

```hcl
lifecycle_rules = [
  {
    id      = "cleanup-temp"
    enabled = true
    prefix  = "temp/"

    expiration_days            = 7  # 7일 후 삭제
    abort_incomplete_upload_days = 1  # 미완료 업로드 1일 후 중단
  }
]
```

### 다단계 아카이빙

```hcl
lifecycle_rules = [
  {
    id      = "multi-tier-archive"
    enabled = true

    transition_to_ia_days      = 90   # 90일: Standard → IA
    transition_to_glacier_days = 365  # 1년: IA → Glacier
    expiration_days            = 2555 # 7년: 삭제

    noncurrent_expiration_days = 90   # 이전 버전 90일 후 삭제
  }
]
```

## 모니터링 및 알람

### 기본 알람 설정

```hcl
enable_cloudwatch_alarms = true
alarm_bucket_size_threshold = 107374182400  # 100GB
alarm_object_count_threshold = 1000000       # 100만 객체
alarm_actions = [aws_sns_topic.ops_alerts.arn]
```

### 알람 유형

1. **Bucket Size Alarm**: 버킷 크기가 임계값을 초과할 때 알림
2. **Object Count Alarm**: 객체 수가 임계값을 초과할 때 알림

### Request Metrics

상세한 S3 요청 메트릭을 활성화하여 성능 모니터링:
```hcl
enable_request_metrics = true
request_metrics_filter_prefix = "critical-data/"  # 특정 접두사만 모니터링
```

## 통합 예제

### CloudWatch Logs 아카이빙

```hcl
module "logs_archive" {
  source = "../../modules/s3-bucket"

  bucket_name = "prod-cloudwatch-logs-archive"

  environment = "prod"
  service_name = "logging"
  team = "platform-team"
  owner = "platform@example.com"
  cost_center = "engineering"
  data_class = "internal"

  kms_key_id = aws_kms_key.logs.arn
  versioning_enabled = true

  lifecycle_rules = [
    {
      id      = "archive-cloudwatch-logs"
      enabled = true

      transition_to_ia_days      = 30
      transition_to_glacier_days = 90
      expiration_days            = 365

      noncurrent_expiration_days   = 30
      abort_incomplete_upload_days = 7
    }
  ]

  logging_enabled = true
  logging_target_bucket = module.audit_logs.bucket_id
  logging_target_prefix = "s3-access/logs-archive/"
}

# CloudWatch Logs 내보내기 설정
resource "aws_cloudwatch_log_export_task" "export" {
  destination      = module.logs_archive.bucket_id
  log_group_name   = "/aws/ecs/my-service"
  from             = 0
  to               = timestamp()
}
```

### Terraform 상태 백엔드

```hcl
module "terraform_state" {
  source = "../../modules/s3-bucket"

  bucket_name = "prod-terraform-state"

  environment = "prod"
  service_name = "terraform"
  team = "platform-team"
  owner = "platform@example.com"
  cost_center = "engineering"
  data_class = "confidential"

  kms_key_id = aws_kms_key.terraform.arn
  versioning_enabled = true  # 상태 파일 버전 관리 필수

  # Terraform 상태는 삭제 방지
  force_destroy = false

  # 액세스 로깅
  logging_enabled = true
  logging_target_bucket = module.audit_logs.bucket_id
  logging_target_prefix = "s3-access/terraform-state/"

  # 모니터링
  enable_cloudwatch_alarms = true
  alarm_actions = [aws_sns_topic.critical_alerts.arn]
}
```

## 종속성

- Terraform >= 1.5.0
- AWS Provider >= 5.0
- `common-tags` 모듈 (내부 종속성)

## 제한사항

### Object Lock

- Object Lock을 활성화하려면 버전 관리가 필수입니다
- Object Lock은 버킷 생성 시에만 활성화 가능합니다
- COMPLIANCE 모드에서는 관리자도 객체를 삭제할 수 없습니다

### 수명 주기 규칙

- 전환 규칙은 순차적이어야 합니다 (STANDARD → IA → GLACIER)
- 최소 전환 기간:
  - STANDARD → STANDARD_IA: 30일
  - STANDARD → GLACIER: 90일

### 정적 웹사이트

- HTTPS는 CloudFront를 통해서만 지원됩니다
- 퍼블릭 액세스 차단을 비활성화해야 합니다

## 라이선스

이 모듈은 내부 인프라 관리용입니다.

## 작성자

Platform Team (platform@example.com)

## 버전

현재 버전: v1.0.0

자세한 변경 이력은 [CHANGELOG.md](./CHANGELOG.md)를 참조하세요.
