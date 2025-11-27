# Infrastructure Repository

AWS 인프라를 관리하는 Terraform 기반 IaC(Infrastructure as Code) 저장소입니다.

## 📋 목차

- [개요](#개요)
- [프로젝트 구조](#프로젝트-구조)
- [Terraform 모듈](#terraform-모듈)
- [환경 관리 (Environments)](#환경-관리-environments)
- [공유 리소스 (Shared)](#공유-리소스-shared)
- [GitHub Actions IAM Role 관리](#github-actions-iam-role-관리)
- [거버넌스 시스템](#거버넌스-시스템)
- [시작하기](#시작하기)
- [마이그레이션 이력](#마이그레이션-이력)

---

## 개요

이 저장소는 AWS 클라우드 인프라를 코드로 관리하며, Terraform과 Atlantis를 통한 자동화된 배포 파이프라인을 제공합니다.

### 주요 특징

- ✅ **Infrastructure as Code**: Terraform으로 모든 인프라 관리
- ✅ **자동화된 거버넌스**: OPA 정책을 통한 자동 검증
- ✅ **PR 기반 워크플로우**: Atlantis를 통한 안전한 배포
- ✅ **재사용 가능한 모듈**: 표준화된 Terraform 모듈
- ✅ **보안 우선**: KMS 암호화, 최소 권한, 보안 스캔

---

## 프로젝트 구조

```
infrastructure/
├── terraform/              # Terraform 인프라 코드
│   ├── modules/           # 18개 재사용 가능한 Terraform 모듈 (v1.0.0)
│   ├── environments/      # 환경별 스택 관리
│   │   └── prod/          # 프로덕션 환경 (11개 스택)
│   │       ├── atlantis/  # Terraform 자동화 서버
│   │       ├── kms/       # KMS 암호화 키
│   │       ├── network/   # VPC, 서브넷, 보안 그룹
│   │       ├── rds/       # RDS PostgreSQL
│   │       ├── alb/       # Application Load Balancer
│   │       ├── ecs-cluster/ # ECS Fargate 클러스터
│   │       ├── fileflow-prod-api-server/ # API 서버
│   │       ├── redis/     # ElastiCache Redis
│   │       ├── sqs/       # SQS 메시지 큐
│   │       ├── eventbridge/ # EventBridge 스케줄러
│   │       └── ecr/       # ECR Container Registry
│   └── shared/            # 공유/임포트 리소스
│       ├── acm/           # ACM SSL 인증서 (임포트)
│       ├── route53/       # Route53 호스팅 존 (임포트)
│       ├── iam-oidc/      # GitHub Actions OIDC Provider
│       └── budget/        # AWS Budget 알림
├── governance/            # 🛡️ 거버넌스 시스템 (품질/보안 검증)
│   ├── configs/           # 검증 도구 설정 (conftest, checkov, tfsec, infracost)
│   ├── policies/          # OPA 정책 (Rego)
│   ├── hooks/             # Git hooks
│   └── scripts/           # 검증 스크립트 (validators, policy)
├── scripts/               # 운영 스크립트 (Git hooks 설치, Docker 빌드)
└── .github/workflows/     # GitHub Actions CI/CD
```

---

## Terraform 모듈

### 🧩 재사용 가능한 인프라 컴포넌트

18개의 프로덕션 레디 Terraform 모듈을 제공합니다.

#### 왜 모듈을 사용해야 하나요?

- ✅ **반복 코드 제거**: 표준화된 컴포넌트 재사용
- ✅ **자동 거버넌스 준수**: KMS 암호화, 필수 태그, 네이밍 강제
- ✅ **검증된 베스트 프랙티스**: Validation, Preconditions, Health Checks 내장
- ✅ **일관성 보장**: 모든 스택에서 동일한 설정 사용

#### 핵심 모듈

| 모듈 | 용도 |
|------|------|
| **ecr** | Container Registry |
| **security-group** | 네트워크 보안 (ALB, ECS, RDS) |
| **ecs-service** | ECS Fargate 서비스 |
| **alb** | Application Load Balancer |
| **iam-role-policy** | IAM 권한 관리 |
| **common-tags** | 태그 표준화 |
| **cloudwatch-log-group** | 로그 관리 |

#### 빠른 시작 (v1.0.0 패턴)

```hcl
# ECR 리포지토리 생성
module "ecr_myapp" {
  source = "../../../modules/ecr"

  name        = "myapp"
  kms_key_arn = data.terraform_remote_state.kms.outputs.ecr_key_arn

  # v1.0.0: 개별 태그 변수 사용
  environment = "prod"
  service_name = "myapp"
  team = "platform-team"
  owner = "platform@example.com"
  cost_center = "engineering"
}

# Security Group 생성 (ALB)
module "sg_alb" {
  source = "../../../modules/security-group"

  name   = "alb-public"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  type   = "alb"  # 미리 정의된 규칙 사용

  alb_enable_https        = true
  alb_ingress_cidr_blocks = ["0.0.0.0/0"]

  # v1.0.0: 개별 태그 변수 사용
  environment = "prod"
  service_name = "alb"
  team = "platform-team"
  owner = "platform@example.com"
  cost_center = "engineering"
}
```

**상세 가이드**:
- [Terraform 모듈 카탈로그](./terraform/modules/README.md)

---

## 환경 관리 (Environments)

### 🌍 environments/

환경별 인프라 스택을 관리하는 디렉토리입니다. 각 환경(dev, staging, prod)은 독립적인 S3 backend와 DynamoDB lock을 사용합니다.

#### 프로덕션 환경 (prod)

11개의 독립적인 스택으로 구성되어 있으며, 각 스택은 독립적인 상태 파일을 관리합니다.

| 카테고리 | 스택 | 설명 |
|---------|------|------|
| **Foundation** | network | VPC, 서브넷, NAT Gateway |
| | kms | 암호화 키 관리 |
| **Security** | atlantis | Terraform 자동화 (ECS) |
| **Application** | ecs-cluster | Fargate 클러스터 |
| | alb | 로드 밸런서 |
| | fileflow-prod-api-server | API 서버 (ECS) |
| | rds | PostgreSQL (db.t4g.micro) |
| | redis | ElastiCache (cache.t4g.micro) |
| | sqs | 메시지 큐 |
| | eventbridge | 스케줄러 |
| | ecr | Container Registry |

#### Backend 구성

```hcl
# terraform/environments/prod/atlantis/backend.tf
terraform {
  backend "s3" {
    bucket         = "prod-connectly-tfstate"
    key            = "atlantis/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
    kms_key_id     = "alias/terraform-state"
  }
}
```

#### 스택 간 참조 (SSM Parameter Store)

```hcl
# network 스택에서 VPC ID 출력 → SSM 저장
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/terraform/prod/network/vpc-id"
  type  = "String"
  value = aws_vpc.main.id
}

# 다른 스택에서 참조
data "aws_ssm_parameter" "vpc_id" {
  name = "/terraform/prod/network/vpc-id"
}

resource "aws_security_group" "example" {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
}
```

**배포 순서**: Foundation (network, kms) → Security (atlantis) → Application (ecs-cluster, alb, ...)

---

## 공유 리소스 (Shared)

### 🔄 shared/

여러 환경에서 공유되거나, 콘솔에서 생성된 리소스를 Terraform으로 임포트하여 관리하는 디렉토리입니다.

#### 공유 리소스 목록

| 리소스 | 타입 | 용도 | 관리 방법 |
|--------|------|------|----------|
| **ACM Certificate** | Import | `*.connectly.ai` SSL 인증서 | 콘솔 생성 → Terraform 임포트 |
| **Route53 Zone** | Import | `connectly.ai` 호스팅 존 | 콘솔 생성 → Terraform 임포트 |
| **IAM OIDC Provider** | Terraform | GitHub Actions 인증 | Terraform으로 생성 |
| **AWS Budget** | Terraform | 비용 알림 ($500/월) | Terraform으로 생성 |

#### Import 전략

```bash
# ACM 인증서 임포트
terraform import aws_acm_certificate.wildcard arn:aws:acm:...

# Route53 호스팅 존 임포트
terraform import aws_route53_zone.main Z1234567890ABC
```

#### SSM Parameter 참조 패턴

```hcl
# shared/acm/main.tf - ACM ARN을 SSM에 저장
resource "aws_ssm_parameter" "acm_arn" {
  name  = "/terraform/shared/acm/certificate-arn"
  type  = "String"
  value = aws_acm_certificate.wildcard.arn
}

# environments/prod/alb/main.tf - 다른 스택에서 참조
data "aws_ssm_parameter" "acm_arn" {
  name = "/terraform/shared/acm/certificate-arn"
}

resource "aws_lb_listener" "https" {
  certificate_arn = data.aws_ssm_parameter.acm_arn.value
}
```


---

## GitHub Actions IAM Role 관리

### 🔐 중앙화된 GitHub Actions 인증

모든 프로젝트 레포지토리는 **단일 IAM Role**을 공유하여 AWS 리소스에 접근합니다. OIDC(OpenID Connect) 기반으로 시크릿 키 없이 안전하게 인증됩니다.

#### Role 정보

| 항목 | 값 |
|------|------|
| **Role Name** | `GitHubActionsRole` |
| **SSM Parameter** | `/github-actions/role-arn` |
| **인증 방식** | GitHub OIDC Federation |
| **관리 위치** | `terraform/environments/prod/bootstrap/github-actions.tf` |

> **Note**: Role ARN은 SSM Parameter Store에 저장되어 있습니다. 직접 노출을 피하고 중앙 관리를 위해 SSM을 통해 조회합니다.

#### 현재 허용된 레포지토리

```
- Infrastructure
- fileflow
- CrawlingHub
- AuthHub
```

> SSM에서 조회: `aws ssm get-parameter --name "/github-actions/allowed-repos" --query "Parameter.Value" --output text`

### 🆕 새 프로젝트 추가 방법

새로운 프로젝트가 AWS 리소스에 접근해야 할 때, 다음 2단계를 수행합니다.

#### Step 1: Infrastructure 레포에서 허용 목록 추가

**파일 위치**: `terraform/environments/prod/bootstrap/variables.tf`

```hcl
variable "allowed_github_repos" {
  description = "List of GitHub repositories allowed to assume the GitHub Actions role"
  type        = list(string)
  default = [
    "Infrastructure",
    "fileflow",
    "CrawlingHub",
    "AuthHub",
    "NewProject"    # ← 여기에 새 프로젝트 추가
  ]
}
```

**적용 방법**:
```bash
cd terraform/environments/prod/bootstrap
terraform plan   # 변경 확인
terraform apply  # 적용
```

또는 PR을 생성하면 Atlantis가 자동으로 plan/apply 합니다.

#### Step 2: 새 프로젝트 레포에서 GitHub Secrets 설정

**1. SSM Parameter에서 Role ARN 조회**:
```bash
# AWS CLI로 Role ARN 조회
aws ssm get-parameter --name "/github-actions/role-arn" --query "Parameter.Value" --output text
```

**2. GitHub Secrets 설정**: `GitHub 레포 → Settings → Secrets and variables → Actions`

| Secret Name | Value |
|-------------|-------|
| `AWS_ROLE_ARN` | (위 명령어로 조회한 ARN 값) |

#### Step 3: 워크플로우에서 Role 사용

새 프로젝트의 `.github/workflows/*.yml` 파일에서:

```yaml
permissions:
  contents: read
  id-token: write  # ← OIDC 토큰 발급에 필요

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-2
          role-duration-seconds: 3600
          role-session-name: GitHubActions-${{ github.repository }}-${{ github.run_id }}
```

### 📋 Role 권한 범위

GitHubActionsRole은 다음 AWS 서비스에 대한 권한을 포함합니다:

| 정책 | 주요 권한 |
|------|----------|
| **TerraformStatePolicy** | S3 state 읽기/쓰기, DynamoDB 락 |
| **InfrastructurePolicy** | VPC, EC2, Security Group, IAM (prod-* 패턴) |
| **ECSPolicy** | ECS 클러스터/서비스/태스크 관리 |
| **ECRPolicy** | ECR 레포지토리 및 이미지 관리 |
| **S3Policy** | S3 버킷 전체 관리 |
| **CloudWatchPolicy** | CloudWatch Logs 및 Alarms |
| **ServicesPolicy** | SQS, ElastiCache, ALB, Route53 |
| **SSMPolicy** | SSM Parameter Store 읽기/쓰기 |
| **KMSPolicy** | KMS 키 관리 |

#### IAM Role 네이밍 규칙

`-prod`, `prod-`, `*-prod-*` 패턴의 Role만 생성/수정 가능합니다:
```
✅ fileflow-prod-task-role
✅ prod-api-execution-role
✅ crawlinghub-prod-scheduler-role
❌ my-custom-role (prod 패턴 없음)
```

### ⚠️ 주의사항

1. **레포 이름은 정확히 일치해야 합니다** (대소문자 구분)
   - ✅ `CrawlingHub` (정확)
   - ❌ `crawlinghub` (실패)

2. **변경 후 반드시 terraform apply** 필요
   - variables.tf만 수정하면 실제 AWS IAM Policy에 반영되지 않음

3. **기존 프로젝트의 Role ARN 변경 시**
   - SSM Parameter 조회: `aws ssm get-parameter --name "/github-actions/role-arn" --query "Parameter.Value" --output text`
   - 이전 개별 Role (예: `crawlinghub-prod-github-actions-role`)은 삭제됨

---

## 거버넌스 시스템

### 🛡️ governance/

Terraform 인프라 코드의 품질, 보안, 컴플라이언스를 **4단계 레이어**에서 자동 검증하는 통합 거버넌스 시스템입니다.

**왜 필요한가?**
- 🛡️ 보안 취약점 사전 차단 (SSH/RDP 인터넷 노출, RDS public access)
- 🏷️ 필수 태그 강제 (리소스 관리, 책임 소재)
- 📏 네이밍 일관성 유지 (kebab-case 강제)
- 🔐 KMS 암호화 강제 (AES256 사용 금지)
- 📋 컴플라이언스 준수 (CIS AWS, PCI-DSS, HIPAA)

**무엇을 검증하는가?**
- **OPA 정책** (policies/): 필수 태그, 네이밍, 보안 그룹, 공개 리소스
- **보안 스캔** (tfsec): AWS 보안 모범 사례
- **컴플라이언스** (Checkov): CIS AWS, PCI-DSS, HIPAA

**자세한 내용**: [governance/README.md](./governance/README.md)

---

## 거버넌스 검증 워크플로우

거버넌스 정책은 **4단계 레이어**에서 자동 검증됩니다 (다층 방어 전략):

### 🔍 검증 레이어

| 레이어 | 시점 | 검증 항목 | 우회 가능 |
|--------|------|----------|----------|
| **Pre-commit** | 커밋 전 | fmt, secrets, validate, OPA | Yes (--no-verify) |
| **Pre-push** | 푸시 전 | tags, encryption, naming | Yes (--no-verify) |
| **Atlantis** | PR plan | OPA 정책 | No |
| **GitHub Actions** | PR 생성 | OPA, tfsec, Checkov | No |

### 🚀 빠른 시작

```bash
# 1. Pre-commit hook 설치 (로컬 검증 활성화)
./scripts/setup-hooks.sh

# 2. Terraform 작업
cd terraform/your-module
terraform init
terraform plan

# 3. 커밋 시 자동 검증
git add .
git commit -m "Add resources"
# → Pre-commit hook이 자동으로 정책 검증

# 4. PR 생성
git push origin feature-branch
# → Atlantis와 GitHub Actions가 자동으로 정책 검증
```

### 📊 검증 결과 확인

- **로컬**: 커밋 시 터미널에 즉시 표시
- **Atlantis**: PR 코멘트에 plan 결과와 함께 표시
- **GitHub Actions**: PR 코멘트에 상세한 검증 리포트


---

## 시작하기

### 필수 요구사항

- Terraform >= 1.5.0
- AWS CLI
- OPA (정책 검증용)
- Conftest (정책 테스트용)

### 설치

```bash
# Terraform
brew install terraform

# OPA
brew install opa

# Conftest
brew install conftest
```

### 기본 사용법

```bash
# 1. Terraform 초기화
cd terraform/your-module
terraform init

# 2. Plan 생성
terraform plan -out=tfplan.binary

# 3. 정책 검증 (선택사항)
terraform show -json tfplan.binary > tfplan.json
conftest test tfplan.json --config ../../conftest.toml

# 4. 적용
terraform apply
```

---

## 관련 문서

### 거버넌스
- [거버넌스 시스템 가이드](./governance/README.md) - **시작점**

### 개발 및 운영
- [Scripts 디렉토리](./scripts/README.md) - Git hooks 설치, Docker 빌드
- [Atlantis 운영 스크립트](./terraform/environments/prod/atlantis/scripts/README.md) - 헬스체크, 로그 모니터링

---

## 마이그레이션 이력

### 📅 2025-11-24: Modules v1.0.0 전환 완료

**변경 사항**:
- ✅ **18개 모듈 v1.0.0 업그레이드**: common_tags map → 개별 태그 변수 전환
- ✅ **11개 prod 스택 리팩토링**: 모든 스택에서 v1.0.0 패턴 적용
- ✅ **태그 변수 표준화**: environment, service_name, team, owner, cost_center
- ✅ **IAM 정책 통합**: 아틀란티스 구형 IAM 역할 삭제, 모듈 기반으로 통합

**영향**:
- 🔧 **모듈 사용법 변경**: 기존 `common_tags = module.common_tags.tags` → 개별 변수 전달
- 📦 **코드 일관성 향상**: 모든 스택에서 동일한 태그 패턴 사용
- 🛡️ **거버넌스 강화**: 필수 태그 변수가 명시적으로 선언되어야 함

**마이그레이션 예시**:

```hcl
# 변경 전 (v0.x)
module "ecr_myapp" {
  source = "../../modules/ecr"

  name        = "myapp"
  kms_key_arn = data.terraform_remote_state.kms.outputs.ecr_key_arn
  common_tags = module.common_tags.tags  # ❌ 이전 패턴
}

# 변경 후 (v1.0.0)
module "ecr_myapp" {
  source = "../../../modules/ecr"

  name        = "myapp"
  kms_key_arn = data.terraform_remote_state.kms.outputs.ecr_key_arn

  # ✅ 개별 태그 변수
  environment  = "prod"
  service_name = "myapp"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```


### 📅 2025-11-21: 거버넌스 시스템 구축

**변경 사항**:
- ✅ **governance/ 디렉토리 구조화**: 4단계 검증 레이어 구축
- ✅ **OPA 정책 통합**: 필수 태그, 네이밍, 보안 그룹, KMS 암호화
- ✅ **보안 스캔 자동화**: tfsec, Checkov, Infracost
- ✅ **Git Hooks 설치**: Pre-commit/Pre-push 검증

**영향**:
- 🛡️ **품질 게이트 강화**: PR 생성 전 로컬에서 정책 검증 가능
- 💰 **비용 통제**: 30% 이상 증가 시 자동 차단
- 📏 **표준 준수**: CIS AWS, PCI-DSS, HIPAA 컴플라이언스

---

**Maintained By**: Platform Team
**Last Updated**: 2025-11-24
