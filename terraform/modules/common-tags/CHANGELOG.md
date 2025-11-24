# Changelog

Common Tags 모듈의 모든 주요 변경 사항은 이 파일에 문서화됩니다.

이 형식은 [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)를 기반으로 하며,
이 프로젝트는 [Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따릅니다.

## [1.0.0] - 2025-11-23

### 개요
Common Tags 모듈의 첫 번째 정식 릴리스입니다. 이 모듈은 infrastructure 프로젝트의 핵심 기반 모듈로, 모든 AWS 리소스에 대한 표준화된 태깅을 제공합니다.

### 추가된 기능

#### 핵심 기능
- **8개 필수 태그 자동 생성**: Owner, CostCenter, Environment, Lifecycle, DataClass, Service, ManagedBy, Project
- **환경별 Lifecycle 자동 매핑**:
  - `prod` → `production`
  - `staging` → `staging`
  - `dev` → `development`
  - 기타 → `temporary`
- **추가 태그 병합 지원**: `additional_tags` 파라미터를 통한 리소스별 고유 태그 추가
- **이중 출력 제공**:
  - `tags`: 필수 태그 + 추가 태그 병합
  - `required_tags`: 필수 태그만 포함

#### 입력 검증 (Validation Rules)
- **environment**: dev, staging, prod만 허용
- **service**: kebab-case 형식 강제
- **team**: kebab-case 형식 강제
- **owner**: 이메일 또는 kebab-case 형식 검증
- **cost_center**: kebab-case 형식 강제
- **managed_by**: terraform, manual, cloudformation, cdk만 허용
- **project**: kebab-case 형식 강제
- **data_class**: confidential, internal, public만 허용

#### 기본값 설정
- `managed_by`: "terraform" (기본값)
- `project`: "infrastructure" (기본값)
- `data_class`: "confidential" (기본값)
- `additional_tags`: {} (빈 맵)

### 거버넌스 준수

#### 태깅 정책
- 모든 AWS 리소스에 8개 필수 태그 강제 적용
- 태그 로직 중앙화로 표준 일관성 보장
- CI/CD 파이프라인을 통한 자동 검증
  - check-tags.sh: 필수 태그 존재 확인
  - check-naming.sh: 명명 규칙 준수 확인
  - conftest: OPA 정책 검증
  - terraform validate: 입력 변수 검증

#### 명명 규칙
- 리소스 변수: kebab-case 강제 (service, team, cost_center, project)
- Owner: 이메일 주소 또는 kebab-case 식별자
- 환경: dev, staging, prod 표준화

### 비용 관리 및 추적

#### AWS Cost Explorer 통합
- **Service 태그**: 서비스별 비용 분석
- **Environment 태그**: 환경별 비용 배분 (dev/staging/prod)
- **CostCenter 태그**: 비용 센터별 청구
- **Project 태그**: 프로젝트별 예산 추적
- **Team 태그**: 팀별 리소스 사용량

### 보안 및 데이터 분류

#### DataClass 기반 보안 정책
- **confidential**: 기밀 데이터 (PII, 민감 정보) - 기본값
- **internal**: 내부 데이터 (분석, 메트릭)
- **public**: 공개 데이터 (정적 콘텐츠)

#### 활용 사례
- KMS 키 선택 자동화
- 암호화 정책 적용
- 접근 제어 정책 설정
- 데이터 보존 정책 관리

### 문서화

#### README.md
- 모듈 개요 및 중요성 설명
- 상세한 사용 예제 (4가지 사용 패턴)
- 입력 변수 및 출력 값 완전한 문서화
- Validation rules 상세 설명
- 모범 사례 4가지
- 문제 해결 가이드
- 비용 추적 및 보안 정책 활용법

#### CHANGELOG.md
- 버전 이력 관리
- Semantic Versioning 준수
- 변경 사항 상세 문서화

### 기술 사양

#### 버전 요구사항
- **Terraform**: >= 1.0
- **AWS Provider**: 제한 없음 (모든 버전 호환)

#### 모듈 구조
```
common-tags/
├── main.tf          # 태그 생성 로직
├── variables.tf     # 입력 변수 및 검증
├── outputs.tf       # 출력 값
├── README.md        # 모듈 문서
└── CHANGELOG.md     # 변경 이력
```

### 사용 예제

#### 기본 사용
```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "api-server"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}

resource "aws_ecr_repository" "app" {
  tags = module.common_tags.tags
}
```

#### 추가 태그와 병합
```hcl
resource "aws_s3_bucket" "logs" {
  tags = merge(
    module.common_tags.tags,
    {
      Name          = "prod-logs"
      RetentionDays = "90"
    }
  )
}
```

### 통합 모듈

이 모듈은 다음 모듈들에서 내부적으로 사용됩니다:
- alb
- cloudfront
- cloudwatch-log-group
- ecr
- ecs-service
- elasticache
- eventbridge
- iam-role-policy
- lambda
- messaging-pattern
- rds
- route53-record
- s3-bucket
- security-group
- sns
- sqs
- waf

### 마이그레이션

#### 기존 var.common_tags 패턴에서 마이그레이션
이전 방식 (비권장):
```hcl
variable "common_tags" {
  type = map(string)
}

resource "aws_instance" "app" {
  tags = var.common_tags
}
```

새로운 방식 (권장):
```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
}

resource "aws_instance" "app" {
  tags = module.common_tags.tags
}
```

### 알려진 제한사항
- 없음

### 향후 계획
- v1.1.0: 추가 거버넌스 태그 지원 검토
- v1.2.0: 커스텀 태그 검증 룰 지원

---

**모듈 버전**: 1.0.0
**릴리스 날짜**: 2025-11-23
**유지 관리**: Platform Team
