# Terraform Infrastructure

환경별로 구조화된 Infrastructure as Code (IaC) 저장소입니다.

## 📁 디렉토리 구조

```
terraform/
├── environments/          # 환경별 운영 스택 (배포 단위)
│   └── prod/
│       ├── acm/          # SSL/TLS 인증서 관리
│       ├── atlantis/     # Terraform 자동화 서버
│       ├── bootstrap/    # 초기 인프라 설정
│       ├── cloudtrail/   # AWS 감사 로깅
│       ├── kms/          # 암호화 키 관리
│       ├── logging/      # 중앙 로깅 인프라
│       ├── monitoring/   # CloudWatch, Prometheus, Grafana
│       ├── network/      # VPC, 서브넷, 보안 그룹
│       ├── rds/          # 관계형 데이터베이스
│       ├── route53/      # DNS 관리
│       └── secrets/      # Secrets Manager
│
├── modules/              # 재사용 가능한 Terraform 모듈
│   ├── common-tags/
│   ├── cloudwatch-log-group/
│   ├── ecs-service/
│   ├── rds/
│   ├── alb/
│   ├── iam-role-policy/
│   └── security-group/
│
├── shared/               # Import된 공유 리소스
│   ├── acm/             # *.set-of.com 인증서
│   ├── route53/         # set-of.com 호스팅 존
│   ├── rds/             # prod-shared-mysql
│   └── vpc/             # prod-shared-vpc
│
└── templates/            # 신규 리소스 생성 템플릿
    ├── acm/
    ├── rds/
    └── route53/
```

## 🎯 디렉토리 역할

### 1. `environments/` - 환경별 운영 스택

**목적**: 실제 AWS 리소스를 배포하는 Terraform 스택

**특징**:
- 환경별 분리 (현재: prod, 향후: dev, staging)
- 각 스택은 독립적인 S3 backend 사용
- 모듈을 조합하여 실제 인프라 구성
- CI/CD로 자동 배포

**Backend 경로**:
```hcl
backend "s3" {
  bucket = "prod-connectly"
  key    = "environments/prod/{stack-name}/terraform.tfstate"
  region = "ap-northeast-2"
  dynamodb_table = "prod-connectly-tf-lock"
  encrypt = true
}
```

**사용 예시**:
```bash
cd terraform/environments/prod/atlantis
terraform init
terraform plan
terraform apply
```

### 2. `modules/` - 재사용 가능한 모듈

**목적**: 여러 스택에서 공통으로 사용하는 Terraform 모듈 (라이브러리)

**특징**:
- 독립적으로 배포되지 않음 (backend 없음)
- 입력 변수를 받아 리소스 생성
- 버전 관리 (CHANGELOG.md)
- 사용 예시 포함 (examples/)

**사용 예시**:
```hcl
# environments/prod/rds/main.tf
module "rds" {
  source = "../../../modules/rds"

  identifier = "prod-mysql"
  engine     = "mysql"
  # ...
}
```

### 3. `shared/` - Import된 공유 리소스

**목적**: 기존 운영 중인 리소스를 Terraform으로 Import하여 관리

**특징**:
- `terraform import`로 기존 리소스 가져오기
- SSM Parameter Store로 다른 스택과 공유
- lifecycle ignore_changes로 기존 속성 보존
- 독립적인 S3 backend

**사용 예시**:
```bash
cd terraform/shared/acm
terraform import aws_acm_certificate.main "arn:aws:acm:..."
terraform apply  # SSM Parameters 생성
```

**크로스 스택 참조**:
```hcl
# 다른 스택에서 사용
data "aws_ssm_parameter" "cert_arn" {
  name = "/shared/connectly/certificate/wildcard-set-of.com/arn"
}

resource "aws_lb_listener" "https" {
  certificate_arn = data.aws_ssm_parameter.cert_arn.value
  # ...
}
```

### 4. `templates/` - 신규 리소스 생성 템플릿

**목적**: 새로운 환경/프로젝트에서 복사해서 사용하는 보일러플레이트

**특징**:
- Backend 설정 주석 처리 (커스터마이징 필요)
- 거버넌스 규칙 적용 (태그, 암호화 등)
- 사용 예시 포함 (terraform.tfvars.example)

**사용 예시**:
```bash
# 새 개발 환경 생성
mkdir -p terraform/environments/dev
cp -r terraform/templates/acm terraform/environments/dev/acm

cd terraform/environments/dev/acm
vi provider.tf  # backend 주석 해제 및 수정
vi terraform.tfvars  # 실제 값 입력
terraform init
terraform apply
```

## 🚀 사용 방법

### 기존 스택 업데이트

```bash
# 1. 해당 스택 디렉토리로 이동
cd terraform/environments/prod/atlantis

# 2. 변경사항 확인
terraform plan

# 3. 적용
terraform apply
```

### 새 환경 추가 (예: dev)

```bash
# 1. 환경 디렉토리 생성
mkdir -p terraform/environments/dev

# 2. 필요한 스택 복사 (템플릿 기반)
cp -r terraform/templates/network terraform/environments/dev/
cp -r terraform/templates/rds terraform/environments/dev/

# 3. Backend 설정 수정
cd terraform/environments/dev/network
vi provider.tf  # key = "environments/dev/network/terraform.tfstate"

# 4. 변수 설정
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars

# 5. 배포
terraform init
terraform apply
```

### 새 모듈 개발

```bash
# 1. 모듈 디렉토리 생성
mkdir -p terraform/modules/my-module

# 2. 모듈 파일 작성
cd terraform/modules/my-module
touch main.tf variables.tf outputs.tf versions.tf README.md CHANGELOG.md

# 3. 예시 디렉토리 생성
mkdir examples/basic

# 4. 스택에서 사용
cd terraform/environments/prod/my-stack
# main.tf에서 module "..." 블록 추가
```

## 📊 State 파일 관리

### Backend 구조

```
S3: prod-connectly
├── environments/prod/atlantis/terraform.tfstate
├── environments/prod/network/terraform.tfstate
├── environments/prod/rds/terraform.tfstate
├── shared/acm/terraform.tfstate
├── shared/route53/terraform.tfstate
└── shared/rds/terraform.tfstate

DynamoDB: prod-connectly-tf-lock
└── LockID (각 스택별 잠금)
```

### State 백업

모든 state 파일은 S3 versioning으로 자동 백업됩니다.

## 🏗️ 아키텍처 패턴

### 1. 환경별 분리

```
environments/
├── prod/      # 프로덕션 (현재)
├── staging/   # 스테이징 (미래)
└── dev/       # 개발 (미래)
```

### 2. 모듈 재사용

```
environments/prod/app1/  ─┐
environments/prod/app2/  ─┼─→  modules/ecs-service/
environments/staging/app/ ─┘
```

### 3. 공유 리소스 참조

```
shared/acm/
  └─→ SSM Parameter: /shared/connectly/certificate/*/arn
         └─→ environments/prod/alb/ (참조)
         └─→ environments/prod/cloudfront/ (참조)
```

## 🔒 보안 및 거버넌스

### 필수 규칙

1. **태그**: 모든 리소스는 `merge(local.required_tags)` 사용
2. **암호화**: KMS 고객 관리형 키 사용 (AES256 금지)
3. **네이밍**: 리소스는 kebab-case, 변수는 snake_case
4. **Backend**: S3 + DynamoDB 필수
5. **State 격리**: 환경별/스택별 분리

### CI/CD 검증

- tfsec: 보안 스캔
- checkov: 컴플라이언스 검증
- Infracost: 비용 영향 분석
- OPA: 정책 검증

## 📚 관련 문서

- [Shared 리소스 가이드](./shared/README.md)
- [Templates 사용 가이드](./templates/README_NEW.md)
- [Module 개발 가이드](./modules/README.md)
- [Infrastructure Governance](../docs/governance/infrastructure_governance.md)

## 🔄 마이그레이션 히스토리

### 2025-11-23: 환경별 구조 재편

기존 flat 구조를 환경별로 재구조화:

```diff
terraform/
- ├── acm/
- ├── atlantis/
- ├── rds/
+ ├── environments/
+ │   └── prod/
+ │       ├── acm/
+ │       ├── atlantis/
+ │       └── rds/
  ├── modules/
  ├── shared/
  └── templates/
```

**변경 사항**:
- 모든 운영 스택을 `environments/prod/`로 이동
- Backend path 업데이트: `{stack}/terraform.tfstate` → `environments/prod/{stack}/terraform.tfstate`
- S3 state 파일 이동 완료 (백업: `backup-migration-2025-11-23/`)

**영향**:
- ✅ 디렉토리 구조 명확화
- ✅ 향후 dev/staging 환경 추가 용이
- ⚠️ 로컬에서 `terraform init -reconfigure` 필요

---

**Last Updated**: 2025-11-23
**Maintained By**: Platform Team
