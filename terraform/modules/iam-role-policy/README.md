# IAM Role Policy Module

표준화된 IAM 역할 및 정책 관리를 위한 Terraform 모듈입니다. ECS, RDS, Secrets Manager, S3, CloudWatch Logs에 대한 사전 정의된 정책 패턴을 제공하며, 최소 권한 원칙과 보안 모범 사례를 준수합니다.

## 주요 기능

- **모듈식 정책 활성화**: 필요한 정책만 선택적으로 활성화하여 최소 권한 원칙 준수
- **사전 정의된 정책 패턴**: ECS, RDS, Secrets Manager, S3, CloudWatch Logs에 대한 보안 검증된 정책
- **KMS 통합**: 모든 서비스에 대한 자동 KMS 암호화/복호화 권한 지원
- **유연한 권한 제어**: 읽기/쓰기 권한을 세밀하게 제어 가능
- **표준 태깅**: common-tags 모듈 통합으로 일관된 태그 관리
- **커스텀 정책**: 사전 정의된 정책 외 커스텀 인라인 정책 지원

## 사용 예제

### 기본 ECS Task Execution Role

ECS 컨테이너가 ECR 이미지를 가져오고 CloudWatch Logs에 로그를 기록할 수 있는 기본 실행 역할:

```hcl
module "ecs_task_execution_role" {
  source = "../../modules/iam-role-policy"

  role_name = "api-server-task-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # 필수 태그
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  # ECS Task Execution 정책 활성화
  enable_ecs_task_execution_policy = true
  ecr_repository_arns = [
    "arn:aws:ecr:ap-northeast-2:123456789012:repository/api-server"
  ]
  cloudwatch_log_group_arns = [
    "arn:aws:logs:ap-northeast-2:123456789012:log-group:/aws/ecs/api-server"
  ]
  kms_key_arns = [
    "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  ]
}
```

### ECS Task Role (애플리케이션 권한)

애플리케이션이 RDS, Secrets Manager, S3에 접근할 수 있는 Task Role:

```hcl
module "ecs_task_role" {
  source = "../../modules/iam-role-policy"

  role_name = "api-server-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # 필수 태그
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  # RDS 접근 권한
  enable_rds_policy = true
  rds_db_instance_arns = [
    "arn:aws:rds:ap-northeast-2:123456789012:db:prod-api-db"
  ]
  rds_iam_db_user_arns = [
    "arn:aws:rds-db:ap-northeast-2:123456789012:dbuser:db-ABCDEFGHIJKLMNOP/app_user"
  ]

  # Secrets Manager 접근 권한
  enable_secrets_manager_policy = true
  secrets_manager_secret_arns = [
    "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:prod/api/database-abc123"
  ]

  # S3 읽기/쓰기 권한
  enable_s3_policy = true
  s3_allow_list    = true
  s3_allow_write   = true
  s3_bucket_arns = [
    "arn:aws:s3:::prod-api-uploads"
  ]
  s3_object_arns = [
    "arn:aws:s3:::prod-api-uploads/*"
  ]

  # CloudWatch Logs 권한
  enable_cloudwatch_logs_policy = true
  cloudwatch_log_group_arns = [
    "arn:aws:logs:ap-northeast-2:123456789012:log-group:/aws/ecs/api-server"
  ]

  # KMS 키 (모든 서비스 암호화/복호화)
  kms_key_arns = [
    "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  ]
}
```

### Lambda 실행 Role with Custom Policy

Lambda 함수가 DynamoDB에 접근하고 커스텀 정책을 포함하는 역할:

```hcl
module "lambda_role" {
  source = "../../modules/iam-role-policy"

  role_name = "data-processor-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # 필수 태그
  environment  = "prod"
  service_name = "data-processor"
  team         = "data-team"
  owner        = "data@example.com"
  cost_center  = "engineering"

  # AWS 관리형 정책 연결
  attach_aws_managed_policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]

  # CloudWatch Logs 권한
  enable_cloudwatch_logs_policy    = true
  cloudwatch_allow_create_log_group = true
  cloudwatch_log_group_arns = [
    "arn:aws:logs:ap-northeast-2:123456789012:log-group:/aws/lambda/data-processor"
  ]

  # 커스텀 DynamoDB 정책
  custom_inline_policies = {
    dynamodb = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Action = [
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ]
          Resource = [
            "arn:aws:dynamodb:ap-northeast-2:123456789012:table/prod-data-table",
            "arn:aws:dynamodb:ap-northeast-2:123456789012:table/prod-data-table/index/*"
          ]
        }]
      })
    }
  }

  # KMS 키
  kms_key_arns = [
    "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  ]
}
```

### Secrets Manager 관리 Role

Secrets Manager 시크릿을 생성, 업데이트, 삭제할 수 있는 관리 역할:

```hcl
module "secrets_admin_role" {
  source = "../../modules/iam-role-policy"

  role_name = "secrets-admin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::123456789012:user/admin"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # 필수 태그
  environment  = "prod"
  service_name = "secrets-management"
  team         = "security-team"
  owner        = "security@example.com"
  cost_center  = "security"

  # Secrets Manager 전체 권한
  enable_secrets_manager_policy    = true
  secrets_manager_allow_create     = true
  secrets_manager_allow_update     = true
  secrets_manager_allow_delete     = true
  secrets_manager_secret_arns = [
    "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:prod/*"
  ]

  # KMS 키
  kms_key_arns = [
    "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  ]
}
```

## 변수 (Variables)

### 필수 변수

| 이름 | 타입 | 설명 | 검증 규칙 |
|------|------|------|----------|
| `assume_role_policy` | `string` | IAM 역할의 신뢰 정책 (AssumeRole policy) | - |
| `role_name` | `string` | IAM 역할 이름 | kebab-case, 64자 이하 |
| `environment` | `string` | 환경 이름 | dev, staging, prod 중 하나 |
| `service_name` | `string` | 서비스 이름 | kebab-case |
| `team` | `string` | 담당 팀 이름 | kebab-case |
| `owner` | `string` | 리소스 소유자 (이메일 또는 식별자) | 이메일 또는 kebab-case |
| `cost_center` | `string` | 비용 센터 | kebab-case |

### 선택 변수 (역할 설정)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `description` | `string` | `""` | IAM 역할 설명 (비어있으면 자동 생성) |
| `max_session_duration` | `number` | `3600` | 최대 세션 시간 (초, 3600-43200) |
| `permissions_boundary` | `string` | `null` | 권한 경계 정책 ARN |
| `project` | `string` | `"infrastructure"` | 프로젝트 이름 (kebab-case) |
| `data_class` | `string` | `"confidential"` | 데이터 분류 (confidential, internal, public) |
| `additional_tags` | `map(string)` | `{}` | 추가 태그 |

### 정책 연결 변수

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `attach_aws_managed_policies` | `list(string)` | `[]` | AWS 관리형 정책 ARN 목록 |
| `custom_inline_policies` | `map(object)` | `{}` | 커스텀 인라인 정책 맵 |

### ECS 정책 변수

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `enable_ecs_task_execution_policy` | `bool` | `false` | ECS Task Execution 정책 활성화 (ECR, CloudWatch Logs) |
| `enable_ecs_task_policy` | `bool` | `false` | ECS Task 정책 활성화 (런타임 권한) |
| `ecr_repository_arns` | `list(string)` | `[]` | ECR 리포지토리 ARN 목록 |
| `ecs_cluster_arns` | `list(string)` | `[]` | ECS 클러스터 ARN 목록 (DescribeTasks 제한) |

### RDS 정책 변수

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `enable_rds_policy` | `bool` | `false` | RDS 접근 정책 활성화 |
| `rds_cluster_arns` | `list(string)` | `[]` | RDS 클러스터 ARN 목록 |
| `rds_db_instance_arns` | `list(string)` | `[]` | RDS DB 인스턴스 ARN 목록 |
| `rds_iam_db_user_arns` | `list(string)` | `[]` | RDS IAM 데이터베이스 인증 사용자 ARN 목록 |

### Secrets Manager 정책 변수

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `enable_secrets_manager_policy` | `bool` | `false` | Secrets Manager 접근 정책 활성화 |
| `secrets_manager_secret_arns` | `list(string)` | `[]` | Secrets Manager 시크릿 ARN 목록 (읽기 권한) |
| `secrets_manager_allow_create` | `bool` | `false` | 시크릿 생성 허용 |
| `secrets_manager_allow_update` | `bool` | `false` | 시크릿 업데이트 허용 |
| `secrets_manager_allow_delete` | `bool` | `false` | 시크릿 삭제 허용 |

### S3 정책 변수

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `enable_s3_policy` | `bool` | `false` | S3 접근 정책 활성화 |
| `s3_bucket_arns` | `list(string)` | `[]` | S3 버킷 ARN 목록 (버킷 레벨) |
| `s3_object_arns` | `list(string)` | `[]` | S3 객체 ARN 목록 (객체 레벨, 일반적으로 bucket_arn/*) |
| `s3_allow_list` | `bool` | `false` | S3 객체 나열 허용 |
| `s3_allow_write` | `bool` | `false` | S3 쓰기 작업 허용 (PutObject, DeleteObject) |

### CloudWatch Logs 정책 변수

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `enable_cloudwatch_logs_policy` | `bool` | `false` | CloudWatch Logs 접근 정책 활성화 |
| `cloudwatch_log_group_arns` | `list(string)` | `[]` | CloudWatch Log Group ARN 목록 |
| `cloudwatch_allow_create_log_group` | `bool` | `false` | 로그 그룹 생성 허용 |

### 암호화 변수

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `kms_key_arns` | `list(string)` | `[]` | KMS 키 ARN 목록 (모든 서비스 암호화/복호화) |

## 출력 (Outputs)

| 이름 | 타입 | 설명 |
|------|------|------|
| `role_arn` | `string` | IAM 역할 ARN |
| `role_name` | `string` | IAM 역할 이름 |
| `role_id` | `string` | IAM 역할 ID |
| `role_unique_id` | `string` | AWS가 할당한 고유 ID |
| `attached_policy_arns` | `list(string)` | 연결된 AWS 관리형 정책 ARN 목록 |
| `inline_policy_names` | `list(string)` | 연결된 인라인 정책 이름 목록 |

## 정책 패턴 상세

### ECS Task Execution Policy

**목적**: ECS 컨테이너가 시작할 때 필요한 인프라 권한

**포함 권한**:
- ECR 이미지 풀 (BatchCheckLayerAvailability, GetDownloadUrlForLayer, BatchGetImage)
- ECR 인증 (GetAuthorizationToken)
- CloudWatch Logs 작성 (CreateLogStream, PutLogEvents)
- KMS 복호화 (ECR 이미지 및 로그 암호화)

**활성화 조건**: `enable_ecs_task_execution_policy = true`

### ECS Task Policy

**목적**: ECS 컨테이너 런타임 중 애플리케이션이 필요한 권한

**포함 권한**:
- ECS 태스크 조회 (DescribeTasks, ListTasks)
- 클러스터 기반 조건부 접근 제어

**활성화 조건**: `enable_ecs_task_policy = true`

### RDS Access Policy

**목적**: RDS 데이터베이스 접근 및 IAM 인증

**포함 권한**:
- RDS 클러스터/인스턴스 조회 (DescribeDBClusters, DescribeDBInstances)
- RDS IAM 데이터베이스 인증 (rds-db:connect)

**활성화 조건**: `enable_rds_policy = true`

**중요**: RDS IAM 인증 사용 시 `rds_iam_db_user_arns`는 다음 형식을 따라야 합니다:
```
arn:aws:rds-db:region:account:dbuser:db-resource-id/db-username
```

### Secrets Manager Policy

**목적**: Secrets Manager 시크릿 읽기/쓰기/관리

**포함 권한**:
- 읽기: GetSecretValue, DescribeSecret (기본)
- 생성: CreateSecret, TagResource (ManagedBy=terraform 태그 필수)
- 업데이트: PutSecretValue, UpdateSecret, UpdateSecretVersionStage
- 삭제: DeleteSecret
- KMS 복호화 (암호화된 시크릿)

**활성화 조건**: `enable_secrets_manager_policy = true`

**보안 특징**: 시크릿 생성 시 `ManagedBy=terraform` 태그 강제

### S3 Access Policy

**목적**: S3 버킷 및 객체 접근

**포함 권한**:
- 버킷 레벨: ListBucket, GetBucketLocation, GetBucketVersioning
- 객체 읽기: GetObject, GetObjectVersion (기본)
- 객체 쓰기: PutObject, DeleteObject (선택)
- KMS 암호화/복호화 (암호화된 객체)

**활성화 조건**: `enable_s3_policy = true`

### CloudWatch Logs Policy

**목적**: CloudWatch Logs 스트림 및 이벤트 작성

**포함 권한**:
- 로그 그룹 생성 (선택, `/aws/*` 프리픽스 제한)
- 로그 스트림 생성/조회 (CreateLogStream, DescribeLogStreams)
- 로그 이벤트 작성 (PutLogEvents)
- KMS 암호화 (암호화된 로그 그룹)

**활성화 조건**: `enable_cloudwatch_logs_policy = true`

**명명 규칙**: 로그 그룹 생성 시 `/aws/*` 프리픽스 강제 (NAMING_CONVENTION.md 준수)

## 보안 고려사항

### 최소 권한 원칙 (Least Privilege)

- **필요한 정책만 활성화**: 각 서비스 정책은 기본적으로 비활성화되어 있으며 명시적으로 활성화 필요
- **ARN 기반 리소스 제한**: 모든 정책은 특정 리소스 ARN에만 권한 부여
- **조건부 접근 제어**: ECS 클러스터, Secrets Manager 태그 등 조건 기반 제한
- **권한 경계 지원**: `permissions_boundary`로 최대 권한 제한 가능

### KMS 암호화 통합

- **통합 KMS 지원**: 단일 `kms_key_arns` 변수로 모든 서비스의 KMS 권한 관리
- **자동 권한 부여**: 서비스별 정책 활성화 시 KMS 복호화 권한 자동 추가
- **최소 KMS 권한**: Decrypt, DescribeKey, Encrypt, GenerateDataKey만 부여

### 보안 모범 사례

1. **ARN 명시**: 와일드카드(*) 최소화, 구체적인 리소스 ARN 사용
2. **세션 시간 제한**: `max_session_duration` 기본값 1시간
3. **태그 강제**: Secrets Manager 생성 시 `ManagedBy=terraform` 태그 필수
4. **로그 그룹 프리픽스**: CloudWatch Logs 생성 시 `/aws/*` 강제
5. **IAM 인증**: RDS IAM 데이터베이스 인증 지원으로 비밀번호 제거

## 태깅 표준

모듈은 `common-tags` 모듈을 통해 다음 필수 태그를 자동 적용합니다:

| 태그 | 소스 | 설명 |
|------|------|------|
| `Environment` | `var.environment` | 환경 (dev, staging, prod) |
| `Service` | `var.service_name` | 서비스 이름 |
| `Team` | `var.team` | 담당 팀 |
| `Owner` | `var.owner` | 리소스 소유자 |
| `CostCenter` | `var.cost_center` | 비용 센터 |
| `Project` | `var.project` | 프로젝트 이름 |
| `DataClass` | `var.data_class` | 데이터 분류 |
| `ManagedBy` | 자동 | `"terraform"` |
| `Name` | `var.role_name` | IAM 역할 이름 |
| `Component` | 자동 | `"iam-role"` |

추가 태그는 `additional_tags` 변수로 병합 가능합니다.

## 의존성

### 모듈 의존성

- `common-tags` 모듈: 표준 태깅 관리

### Provider 요구사항

- Terraform: >= 1.5
- AWS Provider: >= 5.0

### 데이터 소스

- `aws_region.current`: 현재 리전 정보
- `aws_caller_identity.current`: 현재 계정 정보

## 제한사항 및 알려진 이슈

1. **ECR GetAuthorizationToken**: AWS API 제약으로 리소스 ARN 지정 불가, 와일드카드(*) 필수
2. **RDS IAM 인증**: `rds_iam_db_user_arns`는 정확한 ARN 형식 필요
3. **Secrets Manager 생성**: `ManagedBy=terraform` 태그 필수, 다른 태그 사용 불가
4. **CloudWatch Logs 생성**: `/aws/*` 프리픽스만 허용 (프로젝트 명명 규칙)

## 변경 이력

변경 이력은 [CHANGELOG.md](./CHANGELOG.md)를 참조하세요.

## 라이선스

이 모듈은 내부 인프라 관리 목적으로 사용됩니다.

## 지원

문제 또는 질문이 있는 경우 Platform Team에 문의하세요.
