# Environments - 환경별 운영 스택

환경별로 분리된 Terraform 스택 디렉토리입니다.

## 📁 구조

```
environments/
├── prod/              # 프로덕션 환경
│   ├── acm/
│   ├── atlantis/
│   ├── bootstrap/
│   ├── cloudtrail/
│   ├── kms/
│   ├── logging/
│   ├── monitoring/
│   ├── network/
│   ├── rds/
│   ├── route53/
│   └── secrets/
├── staging/           # (미래) 스테이징 환경
└── dev/               # (미래) 개발 환경
```

## 🎯 환경 정의

### Production (`prod/`)

**목적**: 실제 서비스가 운영되는 프로덕션 환경

**특징**:
- High Availability (Multi-AZ)
- 자동 백업 및 복구
- 엄격한 변경 관리
- 24/7 모니터링

**Backend**:
```hcl
backend "s3" {
  bucket = "prod-connectly"
  key    = "environments/prod/{stack-name}/terraform.tfstate"
  region = "ap-northeast-2"
  dynamodb_table = "prod-connectly-tf-lock"
  encrypt = true
}
```

### Staging (`staging/`) - 미래

**목적**: 프로덕션 배포 전 검증 환경

**특징**:
- 프로덕션과 동일한 구성
- 낮은 리소스 스펙
- 자동 테스트 환경

**Backend** (예정):
```hcl
backend "s3" {
  bucket = "staging-connectly"
  key    = "environments/staging/{stack-name}/terraform.tfstate"
  # ...
}
```

### Development (`dev/`) - 미래

**목적**: 개발자용 테스트 환경

**특징**:
- 빠른 반복 개발
- 최소 리소스
- 자유로운 실험

## 🚀 사용 방법

### 기존 스택 업데이트

```bash
# 1. 환경 선택
cd terraform/environments/prod

# 2. 스택 선택
cd atlantis

# 3. 변경사항 확인
terraform plan

# 4. 적용
terraform apply
```

### 새 환경 생성 (예: dev)

```bash
# 1. 환경 디렉토리 생성
mkdir -p terraform/environments/dev

# 2. Templates에서 필요한 스택 복사
cp -r ../../templates/network .
cp -r ../../templates/rds .

# 3. Backend 설정
cd network
vi provider.tf
# backend "s3" 주석 해제 및 수정:
#   bucket = "dev-connectly"
#   key = "environments/dev/network/terraform.tfstate"

# 4. 변수 설정
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
# environment = "dev"
# ...

# 5. 배포
terraform init
terraform apply
```

## 📊 환경별 차이점

| 항목 | Production | Staging | Development |
|-----|-----------|---------|-------------|
| **가용성** | Multi-AZ | Single-AZ | Single-AZ |
| **백업** | 7일 이상 | 3일 | 1일 |
| **인스턴스** | r6g.xlarge | t3.large | t3.medium |
| **Auto Scaling** | Yes | Yes | No |
| **모니터링** | 24/7 | 업무시간 | 기본 |
| **비용** | 높음 | 중간 | 낮음 |

## 🔒 변경 관리

### Production 변경 프로세스

1. **개발**: dev 환경에서 개발 및 테스트
2. **검증**: staging 환경에서 프로덕션 동일 구성 테스트
3. **승인**: PR 리뷰 및 승인
4. **배포**: Atlantis 자동 배포 또는 수동 apply
5. **모니터링**: 배포 후 15분 모니터링

### 긴급 변경 (Hotfix)

```bash
# 1. 긴급 브랜치 생성
git checkout -b hotfix/critical-issue

# 2. 변경 및 테스트
cd terraform/environments/prod/{stack}
terraform plan
terraform apply

# 3. 즉시 PR 및 머지
git commit -am "hotfix: critical security patch"
git push origin hotfix/critical-issue
# PR 생성 및 긴급 리뷰

# 4. 사후 문서화
# docs/incidents/ 에 포스트모템 작성
```

## 🧪 테스트 전략

### Dev → Staging → Prod 흐름

```
1. Dev 환경
   ├─ 기능 개발
   ├─ 단위 테스트
   └─ 통합 테스트

2. Staging 환경
   ├─ E2E 테스트
   ├─ 성능 테스트
   └─ 보안 테스트

3. Production 환경
   ├─ Canary 배포
   ├─ Blue/Green 배포
   └─ 모니터링
```

## 📈 확장 계획

### Phase 1: Staging 환경 추가 (2025 Q1)

```bash
# 1. Backend 설정
aws s3 mb s3://staging-connectly --region ap-northeast-2
aws dynamodb create-table \
  --table-name staging-connectly-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# 2. 환경 구성
mkdir -p terraform/environments/staging
# Templates 기반으로 스택 생성

# 3. CI/CD 파이프라인 추가
# .github/workflows/terraform-staging.yml
```

### Phase 2: Dev 환경 추가 (2025 Q2)

```bash
# Staging과 동일한 프로세스
mkdir -p terraform/environments/dev
# ...
```

## 🔧 환경별 설정 패턴

### 공통 변수 (모든 환경)

```hcl
# common.tfvars (각 환경에서 override)
aws_region   = "ap-northeast-2"
project_name = "connectly"

# Governance tags
owner       = "platform@example.com"
cost_center = "engineering"
```

### 환경별 Override

```hcl
# prod/terraform.tfvars
environment         = "prod"
resource_lifecycle  = "production"
instance_type       = "r6g.xlarge"
multi_az            = true

# dev/terraform.tfvars
environment         = "dev"
resource_lifecycle  = "development"
instance_type       = "t3.medium"
multi_az            = false
```

## 📚 관련 문서

- [Terraform 전체 구조](../README.md)
- [Shared 리소스](../shared/README.md)
- [Templates 가이드](../templates/README_NEW.md)
- [Infrastructure Governance](../../docs/governance/infrastructure_governance.md)

---

**Last Updated**: 2025-11-23
**Maintained By**: Platform Team
