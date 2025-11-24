# Lambda Function Module

> **버전**: v1.0.0
> **최종 수정일**: 2025-11-23

AWS Lambda 함수를 생성하고 관리하는 Terraform 모듈입니다. IAM 역할, VPC 설정, CloudWatch Logs, Dead Letter Queue(DLQ), 버전 관리 등 Lambda 실행에 필요한 모든 리소스를 통합 제공합니다.

## 주요 기능

- **완전한 Lambda 함수 관리**: 런타임, 핸들러, 메모리, 타임아웃 등 모든 설정 지원
- **코드 배포 옵션**: 로컬 파일(`filename`) 또는 S3(`s3_bucket`)를 통한 배포 지원
- **IAM 역할 자동 생성**: Lambda 실행에 필요한 IAM 역할 및 정책 자동 설정
- **VPC 통합**: VPC 내부 리소스 접근을 위한 VPC 설정 지원
- **CloudWatch Logs**: KMS 암호화를 지원하는 로그 그룹 자동 생성
- **Dead Letter Queue (DLQ)**: 실패한 함수 실행을 위한 SQS DLQ 생성 및 권한 설정
- **X-Ray 추적**: AWS X-Ray를 통한 분산 추적 지원
- **함수 별칭(Alias)**: 버전 관리 및 가중치 기반 라우팅 지원
- **Lambda 권한**: 다른 AWS 서비스로부터의 호출 권한 관리
- **계층(Layers)**: Lambda 계층 연결 지원
- **태그 표준화**: `common-tags` 모듈을 통한 일관된 태그 적용

## 사용 예시

### 기본 사용 (로컬 파일 배포)

```hcl
module "api_lambda" {
  source = "../../modules/lambda"

  # Required Tags
  environment = "prod"
  service     = "api-server"
  team        = "backend-team"
  owner       = "backend@example.com"
  cost_center = "engineering"

  # Lambda Configuration
  name        = "process-orders"
  description = "Process customer orders and update inventory"
  handler     = "index.handler"
  runtime     = "nodejs20.x"
  timeout     = 60
  memory_size = 512

  # Code Deployment (로컬 파일)
  filename         = "${path.module}/lambda-package.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda-package.zip")

  # Environment Variables
  environment_variables = {
    DB_HOST     = "prod-db.example.com"
    API_VERSION = "v2"
    LOG_LEVEL   = "info"
  }

  # CloudWatch Logs
  create_log_group    = true
  log_retention_days  = 30
  log_kms_key_id      = aws_kms_key.logs.arn
}
```

### S3 배포 및 VPC 설정

```hcl
module "data_processor" {
  source = "../../modules/lambda"

  # Required Tags
  environment = "prod"
  service     = "data-pipeline"
  team        = "data-engineering"
  owner       = "data@example.com"
  cost_center = "engineering"

  # Lambda Configuration
  name    = "etl-processor"
  handler = "lambda_function.lambda_handler"
  runtime = "python3.11"
  timeout = 300
  memory_size = 2048
  architectures = ["arm64"]  # Graviton2 for cost optimization

  # S3 Deployment
  s3_bucket         = "my-lambda-deployments"
  s3_key            = "etl-processor/v1.2.0/lambda.zip"
  s3_object_version = "abc123xyz456"

  # VPC Configuration (데이터베이스 접근)
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  # Dead Letter Queue (실패 처리)
  create_dlq                     = true
  dlq_message_retention_seconds  = 1209600  # 14 days
  dlq_kms_key_id                 = aws_kms_key.sqs.arn

  # X-Ray Tracing
  tracing_mode = "Active"

  # Lambda Layers
  layers = [
    "arn:aws:lambda:ap-northeast-2:123456789012:layer:pandas:1"
  ]

  # Custom IAM Policies
  custom_policy_arns = {
    s3_access = aws_iam_policy.s3_data_access.arn
    rds_access = aws_iam_policy.rds_connect.arn
  }
}
```

### 별칭(Alias)을 활용한 Blue/Green 배포

```hcl
module "api_function" {
  source = "../../modules/lambda"

  # Required Tags
  environment = "prod"
  service     = "api"
  team        = "platform"
  owner       = "platform@example.com"
  cost_center = "engineering"

  # Lambda Configuration
  name    = "rest-api"
  handler = "app.handler"
  runtime = "python3.11"
  publish = true  # 버전 게시 활성화

  filename         = "${path.module}/api-v2.zip"
  source_code_hash = filebase64sha256("${path.module}/api-v2.zip")

  # Aliases with weighted routing (Canary deployment)
  aliases = {
    prod = {
      description      = "Production alias with canary deployment"
      function_version = "2"  # 새 버전
      routing_config = {
        additional_version_weights = {
          "1" = 0.1  # 10% traffic to old version
        }
      }
    }
    stable = {
      description      = "Stable version"
      function_version = "1"
      routing_config   = null
    }
  }
}
```

### EventBridge로부터 호출 권한 부여

```hcl
module "scheduled_lambda" {
  source = "../../modules/lambda"

  # Required Tags
  environment = "prod"
  service     = "automation"
  team        = "devops"
  owner       = "devops@example.com"
  cost_center = "operations"

  # Lambda Configuration
  name    = "daily-cleanup"
  handler = "index.handler"
  runtime = "nodejs20.x"

  filename         = "${path.module}/cleanup.zip"
  source_code_hash = filebase64sha256("${path.module}/cleanup.zip")

  # Lambda Permissions
  lambda_permissions = {
    allow_eventbridge = {
      action     = "lambda:InvokeFunction"
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.daily_cleanup.arn
    }
  }
}
```

### 기존 IAM 역할 사용

```hcl
module "custom_iam_lambda" {
  source = "../../modules/lambda"

  # Required Tags
  environment = "prod"
  service     = "security"
  team        = "security-team"
  owner       = "security@example.com"
  cost_center = "security"

  # Lambda Configuration
  name    = "audit-processor"
  handler = "handler.main"
  runtime = "python3.11"

  filename         = "${path.module}/audit.zip"
  source_code_hash = filebase64sha256("${path.module}/audit.zip")

  # Use existing IAM role (조직의 표준 역할 사용)
  create_role    = false
  lambda_role_arn = "arn:aws:iam::123456789012:role/standard-lambda-execution-role"

  create_log_group = false  # 기존 로그 그룹 사용
}
```

### 대용량 메모리 및 임시 스토리지 설정

```hcl
module "ml_inference" {
  source = "../../modules/lambda"

  # Required Tags
  environment = "prod"
  service     = "ml-platform"
  team        = "ml-team"
  owner       = "ml@example.com"
  cost_center = "research"

  # Lambda Configuration
  name        = "model-inference"
  handler     = "inference.predict"
  runtime     = "python3.11"
  timeout     = 900  # 15 minutes (max)
  memory_size = 10240  # 10 GB (max)

  # Ephemeral Storage (모델 파일 로드용)
  ephemeral_storage_size = 10240  # 10 GB

  filename         = "${path.module}/inference.zip"
  source_code_hash = filebase64sha256("${path.module}/inference.zip")

  # Reserved concurrency (동시 실행 제한)
  reserved_concurrent_executions = 5

  # Inline IAM Policy (S3 모델 접근)
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::ml-models-bucket",
          "arn:aws:s3:::ml-models-bucket/*"
        ]
      }
    ]
  })
}
```

## 입력 변수

### 필수 태그 변수

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `environment` | `string` | - | 환경 이름 (dev, staging, prod) - **필수** |
| `service` | `string` | - | 서비스 이름 - **필수** |
| `team` | `string` | - | 담당 팀 - **필수** |
| `owner` | `string` | - | 소유자 이메일 주소 - **필수** |
| `cost_center` | `string` | - | 비용 센터 - **필수** |
| `project` | `string` | `"infrastructure"` | 프로젝트 이름 (kebab-case) |
| `data_class` | `string` | `"confidential"` | 데이터 분류 (confidential, internal, public) |

### Lambda 함수 설정

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `name` | `string` | - | Lambda 함수 이름 접미사 (service-environment와 결합) - **필수** |
| `function_name` | `string` | `""` | 전체 Lambda 함수 이름 (자동 생성 이름 재정의) |
| `description` | `string` | `""` | Lambda 함수 설명 |
| `handler` | `string` | - | Lambda 함수 핸들러 (예: index.handler) - **필수** |
| `runtime` | `string` | - | Lambda 런타임 (예: python3.11, nodejs20.x) - **필수** |
| `architectures` | `list(string)` | `["x86_64"]` | 명령어 집합 아키텍처 (x86_64 또는 arm64) |
| `timeout` | `number` | `30` | 함수 타임아웃 (초, 1-900) |
| `memory_size` | `number` | `128` | 메모리 크기 (MB, 128-10240) |
| `reserved_concurrent_executions` | `number` | `-1` | 예약된 동시 실행 수 (-1은 무제한) |

**지원되는 런타임**:
- Python: `python3.9`, `python3.10`, `python3.11`, `python3.12`
- Node.js: `nodejs18.x`, `nodejs20.x`
- Java: `java17`, `java21`
- .NET: `dotnet6`, `dotnet8`
- Go: `go1.x`
- Ruby: `ruby3.2`, `ruby3.3`

### 코드 배포 설정

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `filename` | `string` | `null` | 로컬 배포 패키지 경로 (S3와 상호 배타적) |
| `s3_bucket` | `string` | `null` | 배포 패키지가 있는 S3 버킷 |
| `s3_key` | `string` | `null` | 배포 패키지의 S3 키 |
| `s3_object_version` | `string` | `null` | 배포 패키지의 객체 버전 |
| `source_code_hash` | `string` | `null` | 패키지 파일의 Base64 인코딩 SHA256 해시 |
| `layers` | `list(string)` | `[]` | Lambda Layer ARN 목록 |
| `publish` | `bool` | `false` | 생성/변경을 새 Lambda 함수 버전으로 게시할지 여부 |

**배포 방식 제약 조건**:
- `filename` (로컬 파일)과 `s3_bucket` (S3)는 상호 배타적입니다.
- `filename` 사용 시 `source_code_hash`도 함께 제공해야 합니다.
- `s3_bucket` 사용 시 `s3_key`도 필수입니다.

### 환경 변수 및 VPC 설정

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `environment_variables` | `map(string)` | `null` | 환경 변수 맵 |
| `vpc_config` | `object` | `null` | VPC 설정 (subnet_ids, security_group_ids) |

### IAM 설정

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `create_role` | `bool` | `true` | Lambda 함수용 IAM 역할 생성 여부 |
| `lambda_role_arn` | `string` | `null` | 기존 IAM 역할 ARN (create_role이 false일 때 필수) |
| `custom_policy_arns` | `map(string)` | `{}` | Lambda 역할에 연결할 커스텀 IAM 정책 ARN 맵 |
| `inline_policy` | `string` | `null` | 인라인 IAM 정책 JSON 문서 |

**자동 연결되는 정책**:
- `AWSLambdaBasicExecutionRole`: 기본 CloudWatch Logs 권한
- `AWSLambdaVPCAccessExecutionRole`: VPC 설정 시 자동 연결

### CloudWatch Logs 설정

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `create_log_group` | `bool` | `true` | CloudWatch Log Group 생성 여부 |
| `log_retention_days` | `number` | `14` | CloudWatch Logs 보존 기간 (일) |
| `log_kms_key_id` | `string` | `null` | CloudWatch Logs 암호화용 KMS 키 ID |

**유효한 보존 기간 (일)**: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653

### Dead Letter Queue 설정

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `create_dlq` | `bool` | `false` | Dead Letter Queue 생성 여부 |
| `dlq_message_retention_seconds` | `number` | `1209600` | DLQ 메시지 보존 기간 (초, 60-1209600) |
| `dlq_kms_key_id` | `string` | `null` | DLQ 암호화용 KMS 키 ID |
| `dlq_visibility_timeout_seconds` | `number` | `300` | DLQ visibility timeout (초, 0-43200) |

### 추가 기능 설정

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `tracing_mode` | `string` | `null` | X-Ray 추적 모드 (Active 또는 PassThrough) |
| `ephemeral_storage_size` | `number` | `null` | 임시 스토리지 크기 (MB, 512-10240) |
| `aliases` | `map(object)` | `{}` | Lambda 함수 별칭 맵 |
| `lambda_permissions` | `map(object)` | `{}` | Lambda 권한 설정 맵 |
| `additional_tags` | `map(string)` | `{}` | 공통 태그와 병합할 추가 태그 |

## 출력 값

### Lambda 함수 정보

| 출력 | 설명 |
|------|------|
| `function_name` | Lambda 함수 이름 |
| `function_arn` | Lambda 함수 ARN |
| `function_qualified_arn` | Lambda 함수 Qualified ARN (버전 포함) |
| `function_invoke_arn` | Lambda 함수 Invoke ARN (API Gateway 등에서 사용) |
| `function_version` | 최신 게시 버전 |
| `function_last_modified` | Lambda 함수 최종 수정 날짜 |
| `function_source_code_hash` | 패키지 파일의 Base64 인코딩 SHA256 해시 |
| `function_source_code_size` | 함수 .zip 파일 크기 (바이트) |

### IAM 역할 정보

| 출력 | 설명 |
|------|------|
| `role_arn` | IAM 역할 ARN |
| `role_name` | IAM 역할 이름 |
| `role_id` | IAM 역할 ID |

### CloudWatch Logs 정보

| 출력 | 설명 |
|------|------|
| `log_group_name` | CloudWatch Log Group 이름 |
| `log_group_arn` | CloudWatch Log Group ARN |

### Dead Letter Queue 정보

| 출력 | 설명 |
|------|------|
| `dlq_arn` | Dead Letter Queue ARN |
| `dlq_url` | Dead Letter Queue URL |

### 별칭 및 권한 정보

| 출력 | 설명 |
|------|------|
| `aliases` | Lambda 함수 별칭 맵 (arn, invoke_arn, function_version 포함) |
| `permissions` | Lambda 권한 맵 (statement_id 포함) |

## 리소스 생성

이 모듈은 다음 AWS 리소스를 생성합니다:

| 리소스 | 개수 | 조건 |
|--------|------|------|
| `aws_lambda_function.this` | 1 | 항상 생성 |
| `aws_iam_role.lambda` | 0-1 | `create_role = true`일 때 |
| `aws_iam_role_policy_attachment.basic-execution` | 0-1 | `create_role = true`일 때 |
| `aws_iam_role_policy_attachment.vpc-execution` | 0-1 | `create_role = true` 및 `vpc_config != null`일 때 |
| `aws_iam_role_policy_attachment.custom` | 0-N | `create_role = true` 및 `custom_policy_arns` 개수에 따라 |
| `aws_iam_role_policy.inline` | 0-1 | `create_role = true` 및 `inline_policy != null`일 때 |
| `aws_iam_policy.dlq` | 0-1 | `create_dlq = true` 및 `create_role = true`일 때 |
| `aws_iam_role_policy_attachment.dlq` | 0-1 | `create_dlq = true` 및 `create_role = true`일 때 |
| `aws_cloudwatch_log_group.lambda` | 0-1 | `create_log_group = true`일 때 |
| `aws_sqs_queue.dlq` | 0-1 | `create_dlq = true`일 때 |
| `aws_lambda_alias.this` | 0-N | `aliases` 개수에 따라 |
| `aws_lambda_permission.this` | 0-N | `lambda_permissions` 개수에 따라 |

**의존성 관리**: Lambda 함수는 CloudWatch Log Group, IAM 역할 및 정책 연결이 완료된 후 생성됩니다.

## 거버넌스 및 보안

### 필수 태그

모든 리소스는 `common-tags` 모듈을 통해 다음 필수 태그가 자동으로 적용됩니다:
- `Owner`: 소유자 이메일
- `CostCenter`: 비용 센터
- `Environment`: 환경 (dev, staging, prod)
- `Lifecycle`: 수명 주기 관리
- `DataClass`: 데이터 분류 수준
- `Service`: 서비스 이름

### 보안 모범 사례

1. **KMS 암호화 사용**:
   - CloudWatch Logs: `log_kms_key_id` 설정
   - DLQ: `dlq_kms_key_id` 설정

2. **최소 권한 원칙**:
   - 기본적으로 필요한 최소 권한만 부여 (BasicExecutionRole)
   - 추가 권한은 `custom_policy_arns` 또는 `inline_policy`로 명시적 부여

3. **VPC 격리**:
   - VPC 내부 리소스 접근 시 `vpc_config` 설정
   - 적절한 보안 그룹 및 서브넷 구성

4. **에러 처리**:
   - 프로덕션 환경에서 `create_dlq = true` 설정 권장
   - DLQ 메시지 모니터링 및 알람 설정

5. **버전 관리**:
   - 프로덕션 배포 시 `publish = true` 설정
   - 별칭(Alias)을 활용한 Blue/Green 또는 Canary 배포

### 검증 규칙

모듈은 다음 사전 조건을 검증합니다:

1. **배포 소스 배타성**: `filename`과 `s3_bucket`은 동시에 사용 불가
2. **로컬 배포 해시 필수**: `filename` 사용 시 `source_code_hash` 필수
3. **IAM 역할 요구사항**: `create_role = false`일 때 `lambda_role_arn` 필수
4. **코드 소스 필수**: `filename` 또는 `s3_bucket`+`s3_key` 중 하나 필수

## 호환성

- **Terraform**: >= 1.5.0
- **AWS Provider**: >= 5.0

## 변경 이력

전체 변경 이력은 [CHANGELOG.md](CHANGELOG.md)를 참조하세요.

## 라이선스

이 모듈은 내부 인프라 관리용으로 제작되었습니다.

## 지원 및 문의

- **담당 팀**: Platform Engineering Team
- **문의처**: platform@example.com
- **문서**: [Infrastructure Documentation](../../docs/)

## 기여

모듈 개선을 위한 제안이나 버그 리포트는 이슈를 생성하거나 Pull Request를 제출해 주세요.

### 개발 가이드

1. 변경 사항은 feature 브랜치에서 작업
2. `terraform fmt`, `terraform validate` 실행
3. 거버넌스 검증 통과 (`./scripts/validators/`)
4. CHANGELOG.md 업데이트
5. PR 생성 및 리뷰 요청

## 참고 자료

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Terraform AWS Provider - Lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Lambda Security Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/lambda-security.html)
