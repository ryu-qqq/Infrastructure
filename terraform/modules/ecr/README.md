# ECR 모듈

AWS Elastic Container Registry(ECR)를 생성하고 관리하는 Terraform 모듈입니다. KMS 암호화, 이미지 스캔, 라이프사이클 정책을 포함한 완전한 컨테이너 레지스트리 솔루션을 제공합니다.

## 주요 기능

- **KMS 암호화**: 고객 관리형 KMS 키를 사용한 저장 데이터 암호화 (필수)
- **이미지 스캔**: 푸시 시 자동 보안 취약점 스캔
- **라이프사이클 관리**: 태그된/태그되지 않은 이미지 자동 정리
- **리포지토리 정책**: 사용자 정의 또는 기본 계정 접근 정책
- **SSM 파라미터**: 크로스 스택 참조를 위한 자동 SSM 파라미터 생성
- **태그 관리**: common-tags 모듈과 통합된 표준화된 리소스 태깅
- **유효성 검사**: 입력 값 검증으로 잘못된 구성 방지

## 사용법

### 기본 사용

```hcl
module "app_ecr" {
  source = "../../modules/ecr"

  name        = "api-server"
  kms_key_arn = aws_kms_key.ecr.arn

  # 필수 태그
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

### 고급 구성

```hcl
module "advanced_ecr" {
  source = "../../modules/ecr"

  name                 = "data-processor"
  kms_key_arn          = aws_kms_key.ecr.arn
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true

  # 태그 정보
  environment  = "prod"
  service_name = "data-processor"
  team         = "data-team"
  owner        = "data-team@example.com"
  cost_center  = "data-analytics"
  project      = "ml-pipeline"
  data_class   = "confidential"

  # 라이프사이클 정책 커스터마이징
  enable_lifecycle_policy     = true
  max_image_count             = 50
  lifecycle_tag_prefixes      = ["v", "release", "stable"]
  untagged_image_expiry_days  = 3

  # 추가 태그
  additional_tags = {
    Component   = "ml-training"
    ManagedBy   = "terraform"
  }
}
```

### 사용자 정의 리포지토리 정책

```hcl
module "cross_account_ecr" {
  source = "../../modules/ecr"

  name        = "shared-images"
  kms_key_arn = aws_kms_key.ecr.arn

  # 필수 태그
  environment  = "prod"
  service_name = "shared-registry"
  team         = "platform-team"
  owner        = "devops@example.com"
  cost_center  = "shared-services"

  # 크로스 계정 접근을 위한 사용자 정의 정책
  enable_default_policy = false
  repository_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::111111111111:root",
            "arn:aws:iam::222222222222:root"
          ]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
```

### 최소 구성 (개발 환경)

```hcl
module "dev_ecr" {
  source = "../../modules/ecr"

  name        = "dev-app"
  kms_key_arn = aws_kms_key.ecr.arn

  environment  = "dev"
  service_name = "dev-app"
  team         = "dev-team"
  owner        = "dev@example.com"
  cost_center  = "development"

  # 개발 환경 설정
  image_tag_mutability       = "MUTABLE"
  max_image_count            = 10
  untagged_image_expiry_days = 1
}
```

## 입력 변수

### 필수 변수

| 이름 | 타입 | 설명 | 제약사항 |
|------|------|------|----------|
| `name` | string | ECR 리포지토리 이름 | 소문자/숫자로 시작, 최대 256자 |
| `kms_key_arn` | string | ECR 암호화용 KMS 키 ARN | 유효한 KMS ARN 형식 |
| `environment` | string | 환경 이름 | dev, staging, prod 중 하나 |
| `service_name` | string | 서비스 이름 | kebab-case 형식 |
| `team` | string | 담당 팀 | kebab-case 형식 |
| `owner` | string | 리소스 소유자 | 이메일 또는 kebab-case ID |
| `cost_center` | string | 비용 센터 | kebab-case 형식 |

### 선택 변수 (태그)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `project` | string | "infrastructure" | 프로젝트 이름 |
| `data_class` | string | "confidential" | 데이터 분류 (confidential, internal, public) |
| `additional_tags` | map(string) | {} | 추가 태그 맵 |

### 선택 변수 (리포지토리 구성)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `image_tag_mutability` | string | "MUTABLE" | 이미지 태그 변경 가능 여부 (MUTABLE, IMMUTABLE) |
| `scan_on_push` | bool | true | 푸시 시 이미지 스캔 활성화 |

### 선택 변수 (라이프사이클 정책)

| 이름 | 타입 | 기본값 | 설명 | 제약사항 |
|------|------|--------|------|----------|
| `enable_lifecycle_policy` | bool | true | 라이프사이클 정책 활성화 | - |
| `max_image_count` | number | 30 | 유지할 최대 태그 이미지 수 | 1-1000 |
| `lifecycle_tag_prefixes` | list(string) | ["v"] | 라이프사이클 정책 태그 접두사 | - |
| `untagged_image_expiry_days` | number | 7 | 태그 없는 이미지 삭제 일수 | 1-365 |

### 선택 변수 (리포지토리 정책)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `repository_policy` | string | null | 사용자 정의 리포지토리 정책 JSON |
| `enable_default_policy` | bool | true | 기본 계정 접근 정책 활성화 |

### 선택 변수 (크로스 스택 참조)

| 이름 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `create_ssm_parameter` | bool | true | SSM 파라미터 생성 여부 |

## 출력 값

| 이름 | 설명 | 사용 예시 |
|------|------|-----------|
| `repository_url` | ECR 리포지토리 URL | Docker 푸시/풀 작업 |
| `repository_arn` | ECR 리포지토리 ARN | IAM 정책 참조 |
| `repository_name` | ECR 리포지토리 이름 | 스크립트 참조 |
| `registry_id` | 레지스트리 ID (AWS 계정 ID) | 크로스 계정 설정 |
| `ssm_parameter_arn` | SSM 파라미터 ARN | 크로스 스택 참조 |

## 출력 값 사용 예시

```hcl
# Docker 빌드 및 푸시
output "ecr_login_command" {
  value = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${module.app_ecr.repository_url}"
}

# ECS 태스크 정의에서 이미지 참조
resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([{
    name  = "app"
    image = "${module.app_ecr.repository_url}:latest"
  }])
}

# 다른 스택에서 SSM 파라미터로 참조
data "aws_ssm_parameter" "app_ecr_url" {
  name = "/shared/ecr/api-server-repository-url"
}
```

## 거버넌스 준수

이 모듈은 프로젝트의 거버넌스 표준을 준수합니다:

### 필수 태그
- `Owner`: 리소스 소유자 식별
- `CostCenter`: 비용 추적 및 청구
- `Environment`: 환경 분리 (dev/staging/prod)
- `Lifecycle`: 리소스 수명 주기 관리
- `DataClass`: 데이터 분류 수준
- `Service`: 서비스 식별

### KMS 암호화
- 모든 ECR 리포지토리는 고객 관리형 KMS 키로 암호화됩니다
- AES256 암호화는 사용하지 않습니다
- KMS 키는 자동 로테이션이 활성화되어야 합니다

### 네이밍 규칙
- 리포지토리 이름: kebab-case (예: `api-server`, `data-processor`)
- 변수 및 로컬: snake_case (예: `kms_key_arn`, `service_name`)

### 보안 스캔
- 푸시 시 자동 이미지 스캔 활성화 (기본값)
- 취약점 발견 시 알림 설정 권장

## 라이프사이클 정책 상세

모듈은 두 가지 라이프사이클 규칙을 자동으로 생성합니다:

### 규칙 1: 태그된 이미지 정리
- **우선순위**: 1
- **동작**: 지정된 태그 접두사를 가진 이미지 중 `max_image_count`를 초과하는 오래된 이미지 삭제
- **기본값**: 30개 이미지 유지
- **태그 접두사**: `["v"]` (커스터마이징 가능)

### 규칙 2: 태그 없는 이미지 정리
- **우선순위**: 2
- **동작**: 지정된 일수 이상 된 태그 없는 이미지 삭제
- **기본값**: 7일 후 삭제

### 라이프사이클 정책 비활성화

```hcl
module "no_lifecycle_ecr" {
  source = "../../modules/ecr"

  name        = "long-term-storage"
  kms_key_arn = aws_kms_key.ecr.arn

  environment  = "prod"
  service_name = "archive"
  team         = "ops-team"
  owner        = "ops@example.com"
  cost_center  = "operations"

  enable_lifecycle_policy = false
}
```

## 리포지토리 정책

### 기본 정책 (Same Account)
`enable_default_policy = true`일 때, 동일 AWS 계정 내에서 전체 ECR 작업을 허용하는 정책이 자동 생성됩니다:

- `ecr:GetDownloadUrlForLayer`
- `ecr:BatchGetImage`
- `ecr:BatchCheckLayerAvailability`
- `ecr:PutImage`
- `ecr:InitiateLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:CompleteLayerUpload`

### 사용자 정의 정책
크로스 계정 접근이나 특정 권한 제어가 필요한 경우 `repository_policy` 변수로 사용자 정의 정책을 제공합니다.

## SSM 파라미터 통합

`create_ssm_parameter = true`일 때, 모듈은 자동으로 SSM 파라미터를 생성합니다:

- **파라미터 이름**: `/shared/ecr/{repository-name}-repository-url`
- **값**: ECR 리포지토리 URL
- **타입**: String
- **용도**: 크로스 스택 참조, 외부 스크립트에서 접근

```bash
# CLI로 리포지토리 URL 조회
aws ssm get-parameter --name "/shared/ecr/api-server-repository-url" --query "Parameter.Value" --output text
```

## 운영 가이드

### 이미지 푸시 워크플로우

```bash
# 1. ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin ${REPOSITORY_URL}

# 2. 이미지 빌드
docker build -t api-server:v1.2.3 .

# 3. 이미지 태그
docker tag api-server:v1.2.3 ${REPOSITORY_URL}:v1.2.3
docker tag api-server:v1.2.3 ${REPOSITORY_URL}:latest

# 4. 이미지 푸시
docker push ${REPOSITORY_URL}:v1.2.3
docker push ${REPOSITORY_URL}:latest
```

### 이미지 스캔 결과 조회

```bash
# 스캔 결과 확인
aws ecr describe-image-scan-findings \
  --repository-name api-server \
  --image-id imageTag=v1.2.3 \
  --region ap-northeast-2
```

### 라이프사이클 정책 테스트

```bash
# 현재 라이프사이클 정책 확인
aws ecr get-lifecycle-policy \
  --repository-name api-server \
  --region ap-northeast-2

# 라이프사이클 정책 미리보기 (실제 삭제 안 함)
aws ecr get-lifecycle-policy-preview \
  --repository-name api-server \
  --region ap-northeast-2
```

## 보안 고려사항

### 이미지 취약점 스캔
- 푸시 시 자동 스캔 활성화 (기본값)
- 정기적으로 스캔 결과 검토 및 조치
- 중요도 높은 취약점에 대한 CloudWatch 알람 설정 권장

### 접근 제어
- 최소 권한 원칙 적용
- 프로덕션 환경은 읽기 전용 접근 제한 고려
- 크로스 계정 접근 시 조건 기반 정책 사용

### 암호화
- 고객 관리형 KMS 키 사용 필수
- KMS 키 자동 로테이션 활성화 권장
- 키 정책에서 필요한 서비스만 접근 허용

### 감사 로깅
- CloudTrail로 ECR API 호출 추적
- 이미지 푸시/풀 이벤트 모니터링
- 의심스러운 활동 패턴 감지

## 비용 최적화

### 스토리지 비용
- 라이프사이클 정책으로 불필요한 이미지 자동 삭제
- `max_image_count` 및 `untagged_image_expiry_days` 적절히 조정
- 환경별로 다른 보존 정책 적용

### 데이터 전송 비용
- 동일 리전 내 VPC 엔드포인트 사용 (NAT Gateway 비용 절감)
- 크로스 리전 복제 시 비용 고려

### 모니터링
```hcl
# CloudWatch 메트릭으로 리포지토리 크기 모니터링
resource "aws_cloudwatch_metric_alarm" "ecr_size" {
  alarm_name          = "ecr-${module.app_ecr.repository_name}-size"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RepositorySizeInBytes"
  namespace           = "AWS/ECR"
  period              = "86400"
  statistic           = "Average"
  threshold           = "10737418240"  # 10GB

  dimensions = {
    RepositoryName = module.app_ecr.repository_name
  }
}
```

## 문제 해결

### 일반적인 문제

**문제**: `RequestError: send request failed`
- **원인**: 네트워크 연결 문제 또는 ECR 엔드포인트 접근 불가
- **해결**: VPC 엔드포인트 설정 확인, 보안 그룹 규칙 검토

**문제**: `denied: Your authorization token has expired`
- **원인**: ECR 로그인 토큰 만료 (12시간 유효)
- **해결**: `aws ecr get-login-password` 명령 재실행

**문제**: `RepositoryPolicyNotFoundException`
- **원인**: `enable_default_policy = false` 및 `repository_policy = null`
- **해결**: 둘 중 하나는 활성화 필요

**문제**: KMS 키 접근 거부
- **원인**: ECR 서비스 주체가 KMS 키 정책에 없음
- **해결**: KMS 키 정책에 `ecr.amazonaws.com` 서비스 주체 추가

### 디버깅 팁

```bash
# ECR 리포지토리 상세 정보 확인
aws ecr describe-repositories --repository-names api-server

# 이미지 목록 조회
aws ecr list-images --repository-name api-server

# 리포지토리 정책 확인
aws ecr get-repository-policy --repository-name api-server
```

## 제약사항

- 리포지토리 이름은 생성 후 변경 불가 (재생성 필요)
- KMS 키는 동일 리전에 있어야 함
- 라이프사이클 정책은 최대 50개 규칙까지 지원
- 이미지 태그는 최대 300개까지 가능
- 동시 푸시 제한: 동일 태그에 대해 분당 10회

## 요구사항

### Terraform 버전
- Terraform >= 1.0

### 프로바이더 버전
- AWS Provider >= 4.0

### 필수 리소스
- 고객 관리형 KMS 키 (ECR 암호화용)
- IAM 권한: ECR 리포지토리 생성, 정책 관리, SSM 파라미터 생성

## 관련 모듈

- `common-tags`: 표준화된 리소스 태깅
- `kms`: KMS 키 생성 및 관리
- `iam-role-policy`: ECR 접근을 위한 IAM 역할

## 참고 자료

- [AWS ECR 공식 문서](https://docs.aws.amazon.com/ecr/)
- [ECR 라이프사이클 정책](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html)
- [ECR 보안 모범 사례](https://docs.aws.amazon.com/AmazonECR/latest/userguide/security-best-practices.html)

## 라이선스

이 모듈은 내부 인프라 프로젝트의 일부입니다.

## 작성자

Platform Team

## 변경 이력

변경 사항은 [CHANGELOG.md](CHANGELOG.md)를 참조하세요.
