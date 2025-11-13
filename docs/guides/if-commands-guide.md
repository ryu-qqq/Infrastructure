# Infrastructure Commands (`/if`) 사용 가이드

Infrastructure 프로젝트에서 제공하는 Claude Code 커맨드 전체 가이드입니다.
다른 프로젝트(예: fileflow, api-server)에서 이 infrastructure를 쉽게 활용할 수 있도록 돕습니다.

## 📚 목차

- [개요](#개요)
- [커맨드 목록](#커맨드-목록)
- [Module Commands](#module-commands)
- [Shared Infrastructure Commands](#shared-infrastructure-commands)
- [Atlantis Commands](#atlantis-commands)
- [완전한 워크플로우 예시](#완전한-워크플로우-예시)
- [FAQ](#faq)

---

## 개요

Infrastructure 레포는 두 가지 방식으로 다른 프로젝트를 지원합니다:

| 방식 | 설명 | 사용 커맨드 |
|------|------|------------|
| **모듈 (Module)** | 새로운 리소스를 생성하기 위한 재사용 가능한 템플릿 | `/if/module` |
| **공유 인프라 (Shared)** | 이미 배포된 중앙 인프라를 참조 | `/if/shared` |
| **Atlantis 설정** | PR 기반 Terraform 자동화 설정 | `/if/atlantis` |

### 언제 무엇을 사용하나요?

```
새 ECR 저장소가 필요해요
→ /if/module init ecr

이미 배포된 RDS를 연결하고 싶어요
→ /if/shared get rds

이 프로젝트에 Atlantis를 설정하고 싶어요
→ /if/atlantis init
```

---

## 커맨드 목록

### Module Commands (모듈 관리)

| 커맨드 | 설명 | 예시 |
|--------|------|------|
| `/if/module list` | 사용 가능한 모듈 목록 조회 | `/if/module list` |
| `/if/module info <name>` | 모듈 상세 정보 확인 | `/if/module info ecr` |
| `/if/module get <name>[@version]` | 모듈 참조 코드 출력 | `/if/module get ecr@v1.0.0` |
| `/if/module init <name>[@version]` | 현재 프로젝트에 모듈 설정 파일 생성 | `/if/module init alb` |

### Shared Infrastructure Commands (공유 인프라 참조)

| 커맨드 | 설명 | 예시 |
|--------|------|------|
| `/if/shared list` | 사용 가능한 공유 리소스 목록 | `/if/shared list` |
| `/if/shared info <name>` | 공유 리소스 상세 정보 | `/if/shared info rds` |
| `/if/shared get <name>` | 참조 코드 생성 | `/if/shared get vpc` |

### Atlantis Commands (Terraform 자동화)

| 커맨드 | 설명 | 예시 |
|--------|------|------|
| `/if/atlantis init` | 현재 레포에 atlantis.yaml 생성 | `/if/atlantis init` |
| `/if/atlantis add <project>` | Infrastructure 레포에 프로젝트 추가 | `/if/atlantis add api-server` |

---

## Module Commands

### 개념

**모듈**은 재사용 가능한 Terraform 템플릿입니다. Git 태그로 버전 관리되며, 각 프로젝트에서 독립적으로 사용할 수 있습니다.

**버전 형식**: `modules/{module-name}/v{major}.{minor}.{patch}`

### 사용 가능한 모듈

| 모듈 | 설명 | 최신 버전 |
|------|------|----------|
| `ecr` | Amazon ECR 저장소 | v1.0.0 |
| `alb` | Application Load Balancer | v1.0.0 |
| `ecs-service` | ECS 서비스 (Auto Scaling 포함) | v1.2.0 |
| `rds` | RDS 데이터베이스 | v1.0.0 |
| `cloudwatch-log-group` | CloudWatch 로그 그룹 | v1.0.0 |
| `common-tags` | 표준 태그 세트 | v1.0.0 |
| `iam-role-policy` | IAM 역할 및 정책 | v1.0.0 |
| `security-group` | 보안 그룹 템플릿 | v1.0.0 |

### 워크플로우

#### 1단계: 모듈 목록 확인

```bash
cd ~/your-project
/if/module list
```

**출력 예시**:
```
📦 ecr (v1.0.0)
   📝 Amazon ECR repository with KMS encryption

📦 alb (v1.0.0)
   📝 Application Load Balancer with HTTPS support

📦 ecs-service (v1.2.0)
   📝 ECS Service with Auto Scaling
```

#### 2단계: 모듈 상세 정보 확인

```bash
/if/module info ecr
```

**출력 내용**:
- 모듈 README
- 사용 가능한 변수 목록
- 출력 변수 목록
- 기본 사용 예제

#### 3단계: 프로젝트에 모듈 초기화

```bash
/if/module init ecr@v1.0.0
```

**생성되는 파일**:
```
terraform/
├── provider.tf              # AWS Provider 설정 (신규 생성)
├── variables.tf             # 공통 변수 (신규 생성)
└── ecr/
    ├── main.tf             # 모듈 참조 코드
    ├── outputs.tf          # 출력 변수
    ├── example.tf.template # 사용 예제 (참고용)
    └── variables-reference.tf.md  # 변수 문서
```

#### 4단계: 설정 및 배포

```bash
# 1. main.tf 편집
vim terraform/ecr/main.tf

# 2. Terraform 실행
cd terraform/ecr
terraform init
terraform plan
terraform apply
```

### 실전 예제: FileFlow ECR 설정

```hcl
# terraform/ecr/main.tf
module "ecr" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecr?ref=modules/ecr/v1.0.0"

  repository_name      = "fileflow"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true

  lifecycle_policy = {
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
      }
    ]
  }

  common_tags = {
    Environment = "prod"
    Service     = "fileflow"
    ManagedBy   = "terraform"
  }
}

# terraform/ecr/outputs.tf
output "repository_url" {
  value = module.ecr.repository_url
}

output "repository_arn" {
  value = module.ecr.repository_arn
}
```

### 버전 업그레이드

```bash
# 1. 현재 버전 확인
grep "ref=" terraform/ecr/main.tf

# 2. 새 버전 확인
/if/module info ecr

# 3. main.tf에서 ref 값 변경
# ref=modules/ecr/v1.0.0 → ref=modules/ecr/v1.1.0

# 4. 재초기화
cd terraform/ecr
terraform init -upgrade
terraform plan
```

---

## Shared Infrastructure Commands

### 개념

**공유 인프라**는 Infrastructure 레포에서 중앙 집중식으로 관리하는 리소스입니다.
다른 프로젝트에서는 **SSM Parameter Store**를 통해 읽기 전용으로 참조만 합니다.

### 사용 가능한 공유 리소스

| 리소스 | 설명 | 주요 사용처 |
|--------|------|------------|
| `vpc` | VPC 네트워크 | 보안 그룹, 서브넷 설정 |
| `subnets` | Public/Private/Data 서브넷 | ALB, ECS, RDS 배치 |
| `rds` | 공유 MySQL 데이터베이스 | 애플리케이션 DB 연결 |
| `kms` | KMS 암호화 키 | 리소스 암호화 |
| `amp` | Amazon Managed Prometheus | 메트릭 수집 |
| `amg` | Amazon Managed Grafana | 대시보드 |
| `route53` | Route53 Hosted Zone | DNS 레코드 |
| `acm` | ACM SSL 인증서 | ALB HTTPS |
| `secrets` | Secrets Manager | 시크릿 저장 |
| `cloudtrail` | CloudTrail | 감사 로그 |
| `logging` | 중앙 로깅 (S3) | 로그 저장 |
| `tfstate` | Terraform State 저장소 | Backend 설정 |
| `tflock` | Terraform Lock | State Lock |

### 워크플로우

#### 1단계: 공유 리소스 목록 확인

```bash
cd ~/your-project
/if/shared list
```

**출력 예시**:
```
🌐 vpc
   📝 VPC Network
   📂 terraform/network

📊 rds
   📝 RDS MySQL Database
   📂 terraform/rds

🔑 kms
   📝 KMS Encryption Keys
   📂 terraform/kms
```

#### 2단계: 상세 정보 확인

```bash
/if/shared info rds
```

**출력 내용**:
- SSM Parameter Store 경로
- 현재 AWS에 배포된 실제 값
- Terraform data source 사용 예제
- Secrets Manager 통합 정보

#### 3단계: 참조 코드 생성

```bash
/if/shared get rds
```

**생성 파일**: `/tmp/shared-rds.tf`

```hcl
# Shared Infrastructure Reference: RDS MySQL Database
# Auto-generated by /if/shared get rds

# RDS Connection Information
data "aws_ssm_parameter" "rds_address" {
  name = "/shared/rds/db-instance-address"
}

data "aws_ssm_parameter" "rds_port" {
  name = "/shared/rds/db-instance-port"
}

# RDS Credentials (from Secrets Manager)
data "aws_ssm_parameter" "rds_secret_name" {
  name = "/shared/rds/master-password-secret-name"
}

data "aws_secretsmanager_secret" "rds" {
  name = data.aws_ssm_parameter.rds_secret_name.value
}

data "aws_secretsmanager_secret_version" "rds" {
  secret_id = data.aws_secretsmanager_secret.rds.id
}

# Decoded credentials
locals {
  rds_credentials = jsondecode(data.aws_secretsmanager_secret_version.rds.secret_string)
  rds_username    = local.rds_credentials.username
  rds_password    = local.rds_credentials.password
  rds_dbname      = local.rds_credentials.dbname
  rds_endpoint    = "${data.aws_ssm_parameter.rds_address.value}:${data.aws_ssm_parameter.rds_port.value}"
}
```

#### 4단계: 프로젝트에 복사 및 사용

```bash
# 1. 생성된 파일을 프로젝트로 복사
cp /tmp/shared-rds.tf terraform/shared-rds.tf

# 2. main.tf에서 사용
vim terraform/main.tf
```

### 실전 예제: FileFlow에서 공유 RDS + VPC 사용

```hcl
# terraform/shared-infrastructure.tf

# RDS 참조
data "aws_ssm_parameter" "rds_address" {
  name = "/shared/rds/db-instance-address"
}

data "aws_ssm_parameter" "rds_secret_name" {
  name = "/shared/rds/master-password-secret-name"
}

data "aws_secretsmanager_secret_version" "rds" {
  secret_id = data.aws_secretsmanager_secret.rds.id
}

# VPC 참조
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/vpc/vpc-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/shared/vpc/private-subnet-ids"
}

locals {
  rds_credentials = jsondecode(data.aws_secretsmanager_secret_version.rds.secret_string)
  vpc_id          = data.aws_ssm_parameter.vpc_id.value
  private_subnets = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
}

# terraform/main.tf

# ECS Task Definition에서 RDS 사용
resource "aws_ecs_task_definition" "fileflow" {
  family = "fileflow"

  container_definitions = jsonencode([
    {
      name  = "fileflow"
      image = "${aws_ecr_repository.fileflow.repository_url}:latest"

      environment = [
        {
          name  = "DB_HOST"
          value = data.aws_ssm_parameter.rds_address.value
        },
        {
          name  = "DB_USER"
          value = local.rds_credentials.username
        },
        {
          name  = "DB_NAME"
          value = local.rds_credentials.dbname
        }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = data.aws_secretsmanager_secret.rds.arn
        }
      ]
    }
  ])
}

# 보안 그룹에서 VPC 사용
resource "aws_security_group" "fileflow" {
  vpc_id = local.vpc_id

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}
```

### 주의사항

**✅ Do's**
- 공유 인프라는 읽기 전용으로 참조만 하세요
- SSM Parameter 값은 변경될 수 있으므로 하드코딩 금지
- Secrets Manager를 통해 안전하게 크레덴셜 접근

**❌ Don'ts**
- 공유 인프라를 직접 수정 금지 (Infrastructure 레포에서만 관리)
- `terraform import`로 가져오지 마세요 (data source 사용)
- 크레덴셜을 코드에 직접 저장 금지

---

## Atlantis Commands

### 개념

**Atlantis**는 PR 기반 Terraform 자동화 시스템입니다.
PR을 열면 자동으로 `terraform plan`을 실행하고, PR에 결과를 코멘트로 남깁니다.

### Multi-Repo 아키텍처

```
중앙 Atlantis 서버 (ECS)
    ↓ (github.com/ryu-qqq/* 허용)
    ├─→ Infrastructure 레포 (atlantis.yaml) - 공유 인프라
    ├─→ FileFlow 레포 (atlantis.yaml) - FileFlow 인프라
    └─→ API Server 레포 (atlantis.yaml) - API Server 인프라
```

**핵심**: 각 레포는 자신의 `atlantis.yaml`만 관리합니다.

### 워크플로우

#### 애플리케이션 레포에서 Atlantis 설정 생성

```bash
# 1. 애플리케이션 레포로 이동
cd ~/fileflow

# 2. Atlantis 초기화
/if/atlantis init
```

**출력 예시**:
```
🔍 Scanning terraform directories...

  ✓ Found: terraform/ecr
  ✓ Found: terraform/alb
  ✓ Found: terraform/ecs-service
  ⊗ Found: terraform/dev (excluded by default)

📋 Detected Terraform Projects:

  [x] ecr-prod (terraform/ecr)
      Container Registry for FileFlow

  [x] alb-prod (terraform/alb)
      Application Load Balancer

  [x] ecs-service-prod (terraform/ecs-service)
      ECS Service deployment

  [ ] dev (terraform/dev)
      Development environment (usually skip)

? Include selected projects in atlantis.yaml? (Y/n): y
? Include excluded projects (dev/test)? (y/N): n

✅ Generated: atlantis.yaml
✅ Added 3 projects
```

#### 생성되는 atlantis.yaml 예시

```yaml
version: 3

automerge: false
delete_source_branch_on_merge: false
parallel_plan: true
parallel_apply: false

projects:
  # ============================================================================
  # Container Registry
  # ============================================================================

  # Container Registry for FileFlow
  - name: ecr-prod
    dir: terraform/ecr
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default

  # ============================================================================
  # Load Balancing & CDN
  # ============================================================================

  # Application Load Balancer
  - name: alb-prod
    dir: terraform/alb
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default

  # ============================================================================
  # Application Infrastructure
  # ============================================================================

  # ECS Service deployment
  - name: ecs-service-prod
    dir: terraform/ecs-service
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default

workflows:
  default:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - apply
```

### PR 워크플로우

#### 1단계: Terraform 변경사항 커밋

```bash
# 1. 브랜치 생성
git checkout -b feature/update-ecr-policy

# 2. Terraform 코드 수정
vim terraform/ecr/main.tf

# 3. 커밋 및 푸시
git add terraform/ecr/
git commit -m "feat: Update ECR lifecycle policy"
git push origin feature/update-ecr-policy
```

#### 2단계: GitHub PR 생성

PR을 생성하면 Atlantis가 자동으로:
1. `terraform plan` 실행
2. PR에 Plan 결과 코멘트
3. 변경사항 요약 제공

#### 3단계: 승인 및 적용

```
1. Plan 결과 리뷰
2. PR 승인 (Approve)
3. PR 코멘트에 "atlantis apply" 입력
4. Atlantis가 자동으로 terraform apply 실행
5. 적용 결과 확인 후 PR 머지
```

### Atlantis 커맨드 (PR 코멘트)

| 커맨드 | 설명 |
|--------|------|
| `atlantis plan` | 수동 plan 실행 |
| `atlantis plan -p ecr-prod` | 특정 프로젝트만 plan |
| `atlantis apply` | 모든 프로젝트 apply |
| `atlantis apply -p ecr-prod` | 특정 프로젝트만 apply |
| `atlantis unlock` | Lock 해제 |
| `atlantis help` | 도움말 |

### 무엇을 Atlantis에 포함할까?

**포함 권장 ✅**:
- Production 환경
- Shared 인프라
- 보안 관련 리소스
- 비용이 많이 드는 리소스

**제외 가능 ⊗**:
- Dev/Test 환경
- 임시 리소스
- CI/CD로 관리되는 리소스

---

## 완전한 워크플로우 예시

### 시나리오: FileFlow 프로젝트 인프라 구축

#### 목표
- ECR 저장소 생성
- ALB 설정
- ECS 서비스 배포
- 공유 RDS 연결
- 공유 VPC 사용
- Atlantis 자동화 설정

#### 1단계: 프로젝트 준비

```bash
# FileFlow 프로젝트로 이동
cd ~/fileflow

# 디렉토리 구조 확인
tree -L 2
```

#### 2단계: 모듈 초기화

```bash
# ECR 모듈 초기화
/if/module init ecr@v1.0.0

# ALB 모듈 초기화
/if/module init alb@v1.0.0

# ECS Service 모듈 초기화
/if/module init ecs-service@v1.2.0

# 생성된 구조 확인
tree terraform/
```

**결과**:
```
terraform/
├── provider.tf
├── variables.tf
├── ecr/
│   ├── main.tf
│   ├── outputs.tf
│   └── variables-reference.tf.md
├── alb/
│   ├── main.tf
│   ├── outputs.tf
│   └── variables-reference.tf.md
└── ecs-service/
    ├── main.tf
    ├── outputs.tf
    └── variables-reference.tf.md
```

#### 3단계: 공유 인프라 참조

```bash
# VPC 참조 코드 생성
/if/shared get vpc
cp /tmp/shared-vpc.tf terraform/shared-vpc.tf

# RDS 참조 코드 생성
/if/shared get rds
cp /tmp/shared-rds.tf terraform/shared-rds.tf

# ACM 참조 코드 생성 (HTTPS 인증서)
/if/shared get acm
cp /tmp/shared-acm.tf terraform/shared-acm.tf
```

#### 4단계: Terraform 코드 작성

**terraform/ecr/main.tf**:
```hcl
module "ecr" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecr?ref=modules/ecr/v1.0.0"

  repository_name      = "fileflow"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true

  lifecycle_policy = {
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
      }
    ]
  }

  common_tags = {
    Environment = "prod"
    Service     = "fileflow"
    ManagedBy   = "terraform"
  }
}
```

**terraform/alb/main.tf**:
```hcl
module "alb" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/alb?ref=modules/alb/v1.0.0"

  name               = "fileflow-alb"
  vpc_id             = local.vpc_id
  subnets            = local.public_subnets
  security_group_ids = [aws_security_group.alb.id]

  certificate_arn = local.certificate_arn

  common_tags = {
    Environment = "prod"
    Service     = "fileflow"
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "alb" {
  name        = "fileflow-alb-sg"
  description = "Security group for FileFlow ALB"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fileflow-alb-sg"
  }
}
```

**terraform/ecs-service/main.tf**:
```hcl
module "ecs_service" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecs-service?ref=modules/ecs-service/v1.2.0"

  cluster_id      = data.aws_ecs_cluster.main.id
  service_name    = "fileflow"
  task_definition = aws_ecs_task_definition.fileflow.arn
  desired_count   = 2

  load_balancer = {
    target_group_arn = module.alb.target_group_arn
    container_name   = "fileflow"
    container_port   = 8080
  }

  common_tags = {
    Environment = "prod"
    Service     = "fileflow"
    ManagedBy   = "terraform"
  }
}

resource "aws_ecs_task_definition" "fileflow" {
  family                   = "fileflow"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([
    {
      name  = "fileflow"
      image = "${module.ecr.repository_url}:latest"

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DB_HOST"
          value = local.rds_endpoint
        },
        {
          name  = "DB_USER"
          value = local.rds_username
        },
        {
          name  = "DB_NAME"
          value = local.rds_dbname
        }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = data.aws_secretsmanager_secret.rds.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/fileflow"
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "fileflow"
        }
      }
    }
  ])
}
```

#### 5단계: Terraform 배포

```bash
# ECR 먼저 배포
cd terraform/ecr
terraform init
terraform plan
terraform apply

# Docker 이미지 빌드 및 푸시
docker build -t fileflow:latest .
docker tag fileflow:latest $(terraform output -raw repository_url):latest
docker push $(terraform output -raw repository_url):latest

# ALB 배포
cd ../alb
terraform init
terraform plan
terraform apply

# ECS Service 배포
cd ../ecs-service
terraform init
terraform plan
terraform apply
```

#### 6단계: Atlantis 설정

```bash
# 프로젝트 루트로 이동
cd ~/fileflow

# Atlantis 설정 생성
/if/atlantis init

# 생성된 atlantis.yaml 확인
cat atlantis.yaml

# Git에 커밋
git add atlantis.yaml
git commit -m "feat: Add Atlantis configuration"
git push origin main
```

#### 7단계: PR 기반 워크플로우 테스트

```bash
# 테스트 브랜치 생성
git checkout -b test/atlantis-integration

# Terraform 코드 수정 (예: desired_count 변경)
vim terraform/ecs-service/main.tf

# 커밋 및 푸시
git add terraform/ecs-service/main.tf
git commit -m "test: Update ECS desired count"
git push origin test/atlantis-integration

# GitHub에서 PR 생성
# → Atlantis가 자동으로 plan 실행
# → PR 코멘트에서 결과 확인
# → "atlantis apply" 코멘트로 적용
```

---

## FAQ

### 일반 질문

**Q: Module과 Shared의 차이가 뭔가요?**

A:
- **Module**: 새 리소스를 만드는 템플릿 (ECR, ALB, ECS 등)
- **Shared**: 이미 만들어진 리소스를 참조 (VPC, RDS, KMS 등)

**Q: 모듈 버전은 어떻게 선택하나요?**

A: 프로덕션에서는 항상 특정 버전을 사용하세요 (예: `@v1.0.0`). `main` 브랜치는 개발/테스트 환경에서만 사용하세요.

**Q: 모듈을 수정하고 싶어요.**

A: Infrastructure 레포에서 수정 → Git 태그 생성 → 다른 프로젝트에서 새 버전 참조

**Q: Private repository에서 작동하나요?**

A: 네, SSH 키 또는 Git credentials가 설정되어 있으면 됩니다.

### Module 관련

**Q: 모듈 초기화 시 어떤 파일들이 생성되나요?**

A: `terraform/{module-name}/` 디렉토리에 `main.tf`, `outputs.tf`, `example.tf.template`, `variables-reference.tf.md`가 생성됩니다.

**Q: 여러 프로젝트에서 같은 모듈의 다른 버전을 사용할 수 있나요?**

A: 네, 각 프로젝트는 독립적으로 버전을 관리합니다.

**Q: 모듈 버전을 업그레이드하려면?**

A: `main.tf`에서 `ref` 값을 변경 → `terraform init -upgrade` 실행

### Shared Infrastructure 관련

**Q: SSM Parameter 값이 변경되면 어떻게 하나요?**

A: `terraform refresh` 또는 `terraform plan`을 실행하면 자동으로 최신 값을 가져옵니다.

**Q: 공유 인프라를 수정하고 싶어요.**

A: Infrastructure 레포의 해당 Terraform 코드를 수정하고 배포해야 합니다. 다른 프로젝트에서는 읽기 전용입니다.

**Q: 모든 공유 리소스를 반드시 사용해야 하나요?**

A: 아니요, 프로젝트에 필요한 리소스만 참조하세요.

**Q: 여러 환경(dev/staging/prod)에서 다른 공유 인프라를 참조할 수 있나요?**

A: 네, SSM Parameter 경로에 환경 접두사를 추가하면 됩니다 (예: `/dev/shared/rds/...`).

### Atlantis 관련

**Q: 모든 Terraform 프로젝트를 Atlantis에 포함해야 하나요?**

A: 아니요. Production, shared infrastructure, 보안 관련 리소스는 포함하되, dev/test 환경이나 임시 리소스는 제외할 수 있습니다.

**Q: Atlantis가 plan은 실행했는데 apply는 안 돼요.**

A: `apply_requirements: ["approved", "mergeable"]` 때문입니다. PR을 먼저 승인(Approve)해야 apply가 가능합니다.

**Q: dev 환경도 Atlantis로 관리하고 싶어요.**

A: `/if/atlantis init` 실행 시 "Include excluded projects?" 질문에 `y`를 입력하면 dev/test 프로젝트도 포함됩니다.

---

## 추가 참고 자료

- **Module 개발 가이드**: `docs/modules/README.md`
- **Atlantis 운영 가이드**: `docs/guides/atlantis-operations-guide.md`
- **Multi-Repo 아키텍처**: `docs/architecture/multi-repo-strategy.md`
- **SSM Parameter Store 가이드**: `docs/guides/ssm-parameters.md`

---

## 도움이 필요하신가요?

1. **Claude Code에서**: `/if/help` 실행
2. **문서 확인**: `docs/` 디렉토리
3. **예제 확인**: `terraform/modules/{module-name}/examples/`
4. **Issue 등록**: GitHub Issues

---

**Last Updated**: 2025-01-13
**Version**: 1.0.0
