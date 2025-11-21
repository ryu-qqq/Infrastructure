# Terraform으로 인프라 코드화하기 – Terraform (3)

## 🎯 왜 모듈화가 필요한가?

Terraform 코드를 작성하다 보면 같은 패턴이 반복됩니다:

```hcl
# ❌ 반복되는 코드 (Bad Practice)
# dev/security-groups.tf
resource "aws_security_group" "api_server_dev" {
  name        = "api-server-dev"
  description = "Security group for API server in dev"
  vpc_id      = aws_vpc.dev.id

  tags = {
    Environment = "dev"
    Service     = "api-server"
    Team        = "platform"
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
  }
}

# staging/security-groups.tf
resource "aws_security_group" "api_server_staging" {
  name        = "api-server-staging"
  description = "Security group for API server in staging"
  vpc_id      = aws_vpc.staging.id

  tags = {
    Environment = "staging"
    Service     = "api-server"
    Team        = "platform"
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
  }
}

# prod/security-groups.tf
resource "aws_security_group" "api_server_prod" {
  name        = "api-server-prod"
  description = "Security group for API server in prod"
  vpc_id      = aws_vpc.prod.id

  tags = {
    Environment = "prod"
    Service     = "api-server"
    Team        = "platform"
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
  }
}
```

**문제점:**
- 🔴 중복 코드가 많음 (DRY 원칙 위반)
- 🔴 태그가 하나 바뀌면 3곳을 모두 수정해야 함
- 🔴 실수로 한 곳만 수정하면 불일치 발생
- 🔴 새 환경 추가 시 복사-붙여넣기 오류 가능성

## ✅ 모듈을 사용한 해결책

```hcl
# ✅ 모듈 정의 (modules/security-group/main.tf)
resource "aws_security_group" "this" {
  name        = "${var.name}-${var.environment}"
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.name}-${var.environment}"
      Environment = var.environment
    }
  )
}

# ✅ 모듈 사용 (각 환경에서)
module "api_server_sg" {
  source = "../../modules/security-group"

  name        = "api-server"
  environment = "dev"  # 또는 "staging", "prod"
  vpc_id      = aws_vpc.main.id
  description = "Security group for API server"

  common_tags = local.required_tags
}
```

**장점:**
- ✅ 코드 중복 제거 (DRY)
- ✅ 일관성 보장 (모든 환경에서 동일한 패턴)
- ✅ 유지보수 용이 (한 곳만 수정하면 됨)
- ✅ 테스트 가능 (모듈 단위로 검증)
- ✅ 재사용 가능 (다른 프로젝트에서도 사용)

## 📁 모듈 디렉토리 구조

### 표준 모듈 구조

```
terraform/modules/{module-name}/
├── README.md              # 📖 모듈 사용법 문서
├── main.tf                # 🏗️ 주요 리소스 정의
├── variables.tf           # 📥 입력 변수 선언
├── outputs.tf             # 📤 출력 값 선언
├── versions.tf            # 🔖 Provider 버전 제약
├── CHANGELOG.md           # 📋 버전 히스토리
└── examples/              # 💡 사용 예시
    ├── basic/
    │   ├── main.tf
    │   └── README.md
    └── advanced/
        ├── main.tf
        └── README.md
```

### 프로젝트의 실제 모듈

```
terraform/modules/
├── common-tags/           # 🏷️ 표준 태그 관리
├── cloudwatch-log-group/  # 📊 로그 그룹 (암호화 포함)
├── ecs-service/           # 🐳 ECS 서비스 배포
├── rds/                   # 💾 RDS 인스턴스 (Multi-AZ)
├── alb/                   # ⚖️ Application Load Balancer
├── iam-role-policy/       # 🔐 IAM 역할/정책 관리
└── security-group/        # 🛡️ Security Group 템플릿
```

## 🏷️ 모듈 1: Common Tags (필수 태그 관리)

### 문제: 태그 불일치

```hcl
# ❌ 각 리소스마다 태그를 다르게 작성
resource "aws_instance" "web" {
  tags = {
    Environment = "Production"  # 대문자
    Owner = "platform@example.com"
  }
}

resource "aws_s3_bucket" "data" {
  tags = {
    environment = "prod"  # 소문자, 다른 값
    owner = "platform@example.com"
  }
}

# 태그가 일관되지 않아서:
# - 비용 보고서에서 리소스를 제대로 그룹핑 못함
# - 자동화 스크립트가 태그를 찾지 못함
# - 거버넌스 정책 위반
```

### 해결: Common Tags 모듈

```hcl
# modules/common-tags/main.tf
locals {
  required_tags = {
    Environment = var.environment
    Service     = var.service
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    Project     = var.project
  }
}

# modules/common-tags/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "service" {
  description = "Service name"
  type        = string
}

# ... 다른 변수들

# modules/common-tags/outputs.tf
output "tags" {
  description = "Standard tags for all resources"
  value       = local.required_tags
}
```

### 사용 예시

```hcl
# terraform/network/main.tf
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "network"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  project     = "infrastructure"
}

# 모든 리소스에서 재사용
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = merge(
    module.common_tags.tags,
    {
      Name = "prod-main-vpc"
    }
  )
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = merge(
    module.common_tags.tags,
    {
      Name = "prod-public-subnet-1a"
      Type = "public"
    }
  )
}
```

**장점:**
- ✅ 모든 리소스가 동일한 태그 구조 사용
- ✅ 태그 값 검증 (validation 블록)
- ✅ 비용 추적 용이
- ✅ 거버넌스 정책 준수

## 📊 모듈 2: CloudWatch Log Group (암호화 로깅)

### 문제: 로그 관리 일관성 부족

```hcl
# ❌ 각 서비스마다 다른 로그 설정
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/api/logs"
  retention_in_days = 7  # 짧은 보존 기간
  # KMS 암호화 없음 - 보안 문제!
}

resource "aws_cloudwatch_log_group" "worker_logs" {
  name              = "/service/worker"  # 일관되지 않은 네이밍
  retention_in_days = 30
  kms_key_id       = "arn:aws:kms:..."  # 하드코딩
}
```

### 해결: CloudWatch Log Group 모듈

```hcl
# modules/cloudwatch-log-group/main.tf
resource "aws_cloudwatch_log_group" "this" {
  name              = var.name
  retention_in_days = var.retention_in_days
  kms_key_id        = var.kms_key_id

  tags = merge(
    var.common_tags,
    {
      Name      = var.name
      Component = var.component
    }
  )
}

# modules/cloudwatch-log-group/variables.tf
variable "name" {
  description = "Log group name (e.g., /aws/ecs/api-server/application)"
  type        = string
}

variable "retention_in_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30

  validation {
    condition     = contains([7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.retention_in_days)
    error_message = "Retention period must be a valid CloudWatch Logs retention value."
  }
}

variable "kms_key_id" {
  description = "KMS key ARN for log encryption"
  type        = string
}

# modules/cloudwatch-log-group/outputs.tf
output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.this.arn
}
```

### 사용 예시

```hcl
# terraform/services/api-server/logs.tf
module "app_logs" {
  source = "../../modules/cloudwatch-log-group"

  name              = "/aws/ecs/api-server/application"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
  component         = "application"
  common_tags       = module.common_tags.tags
}

module "access_logs" {
  source = "../../modules/cloudwatch-log-group"

  name              = "/aws/ecs/api-server/access"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.logs.arn
  component         = "access"
  common_tags       = module.common_tags.tags
}

# ECS Task Definition에서 사용
resource "aws_ecs_task_definition" "api" {
  # ...
  container_definitions = jsonencode([{
    name  = "api-server"
    image = "my-api:latest"

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = module.app_logs.log_group_name
        "awslogs-region"        = "ap-northeast-2"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}
```

**장점:**
- ✅ 모든 로그가 KMS 암호화 (보안)
- ✅ 일관된 네이밍 규칙
- ✅ 유효성 검증 (retention 값)
- ✅ 표준 태그 자동 적용

## 💾 모듈 3: RDS (Multi-AZ 데이터베이스)

### 실제 모듈 구조

```hcl
# modules/rds/main.tf
resource "aws_db_instance" "this" {
  identifier     = "${var.identifier}-${var.environment}"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # 스토리지
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true
  kms_key_id           = var.kms_key_id

  # 네트워크
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false  # 절대 public으로 노출하지 않음

  # 고가용성
  multi_az               = var.multi_az

  # 백업
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  # 성능
  performance_insights_enabled = var.performance_insights_enabled

  # 인증
  username = var.username
  password = var.password  # Secrets Manager에서 가져옴

  # 삭제 보호
  deletion_protection       = var.deletion_protection
  skip_final_snapshot      = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.identifier}-${var.environment}"
    }
  )
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-${var.environment}"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.common_tags,
    {
      Name = "${var.identifier}-subnet-group"
    }
  )
}

# modules/rds/variables.tf
variable "identifier" {
  description = "Database identifier"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "engine" {
  description = "Database engine (postgres, mysql)"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "Instance class (db.t3.micro, db.r6g.large, etc.)"
  type        = string
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true  # 기본적으로 고가용성 활성화
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true  # 실수로 삭제 방지
}

# modules/rds/outputs.tf
output "endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Database address (hostname)"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Database port"
  value       = aws_db_instance.this.port
}

output "arn" {
  description = "Database ARN"
  value       = aws_db_instance.this.arn
}
```

### 사용 예시

```hcl
# terraform/database/main.tf

# 1. KMS 키 생성 (DB 암호화용)
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = module.common_tags.tags
}

# 2. Secrets Manager에서 DB 비밀번호 가져오기
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "rds/prod/master-password"
}

# 3. RDS 모듈 사용
module "main_db" {
  source = "../../modules/rds"

  identifier    = "api-server-db"
  environment   = "prod"

  # 엔진 설정
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.r6g.large"

  # 스토리지
  allocated_storage     = 100
  max_allocated_storage = 500
  storage_type          = "gp3"
  kms_key_id           = aws_kms_key.rds.arn

  # 네트워크
  subnet_ids         = data.aws_subnets.database.ids
  security_group_ids = [aws_security_group.rds.id]

  # 고가용성
  multi_az = true  # Production은 반드시 Multi-AZ

  # 백업 (매일 새벽 3시, 7일 보존)
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  # 성능 모니터링
  performance_insights_enabled = true

  # 인증
  username = "dbadmin"
  password = data.aws_secretsmanager_secret_version.db_password.secret_string

  # 삭제 보호 (Production은 반드시 활성화)
  deletion_protection  = true
  skip_final_snapshot = false

  common_tags = module.common_tags.tags
}

# 4. SSM Parameter Store에 엔드포인트 저장 (다른 서비스에서 참조)
resource "aws_ssm_parameter" "db_endpoint" {
  name  = "/prod/database/main/endpoint"
  type  = "String"
  value = module.main_db.endpoint

  tags = module.common_tags.tags
}
```

**장점:**
- ✅ Multi-AZ 자동 구성 (고가용성)
- ✅ KMS 암호화 필수
- ✅ 자동 백업 설정
- ✅ 삭제 보호 활성화
- ✅ Performance Insights 포함
- ✅ Final Snapshot 자동 생성

## 🔐 거버넌스: 모듈에서 정책 강제하기

### 필수 태그 검증

```hcl
# modules/common-tags/main.tf
variable "environment" {
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "❌ Environment must be one of: dev, staging, prod"
  }
}

variable "owner" {
  description = "Owner email address"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner))
    error_message = "❌ Owner must be a valid email address"
  }
}
```

### 암호화 강제

```hcl
# modules/cloudwatch-log-group/main.tf
resource "aws_cloudwatch_log_group" "this" {
  name              = var.name
  retention_in_days = var.retention_in_days
  kms_key_id        = var.kms_key_id  # 필수 입력

  # kms_key_id가 없으면 에러 발생
  lifecycle {
    precondition {
      condition     = var.kms_key_id != null && var.kms_key_id != ""
      error_message = "❌ KMS key is required for log encryption"
    }
  }
}
```

### 네이밍 규칙 강제

```hcl
# modules/rds/main.tf
resource "aws_db_instance" "this" {
  identifier = "${var.identifier}-${var.environment}"

  lifecycle {
    precondition {
      condition     = can(regex("^[a-z][a-z0-9-]*$", var.identifier))
      error_message = "❌ Identifier must start with letter, contain only lowercase letters, numbers, and hyphens"
    }
  }

  # ...
}
```

## 📦 모듈 버전 관리

### 방법 1: Git 태그 사용

```hcl
# terraform/services/api-server/main.tf
module "app_logs" {
  source = "git::https://github.com/yourorg/terraform-modules.git//cloudwatch-log-group?ref=v1.2.0"

  # ...
}
```

### 방법 2: 로컬 모듈 + CHANGELOG

```markdown
# modules/cloudwatch-log-group/CHANGELOG.md
## [1.2.0] - 2024-01-15
### Added
- KMS encryption support
- Retention validation

### Changed
- Default retention changed from 7 to 30 days

### Breaking Changes
- `kms_key_id` is now required (was optional)
```

## 🎓 모듈 작성 Best Practices

### 1. 단일 책임 원칙
```hcl
# ✅ Good: 한 가지만 잘하는 모듈
module "log_group" {
  source = "../../modules/cloudwatch-log-group"
  # CloudWatch Log Group 생성만 담당
}

# ❌ Bad: 너무 많은 책임
module "complete_app" {
  source = "../../modules/complete-app"
  # VPC, ALB, ECS, RDS, CloudWatch, S3 모두 포함
  # → 재사용 어려움, 유연성 부족
}
```

### 2. 합리적인 기본값

```hcl
# modules/rds/variables.tf
variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true  # ✅ 프로덕션 기준으로 안전한 기본값
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true  # ✅ 실수 방지
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7  # ✅ 최소 7일은 백업 보존
}
```

### 3. 명확한 변수 검증

```hcl
variable "instance_class" {
  description = "RDS instance class"
  type        = string

  validation {
    condition = can(regex("^db\\.(t3|r6g|m6g)\\.", var.instance_class))
    error_message = "❌ Only t3, r6g, m6g instance classes are allowed for cost optimization"
  }
}
```

### 4. 풍부한 출력값

```hcl
# modules/rds/outputs.tf
output "endpoint" {
  description = "Database connection endpoint (hostname:port)"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Database hostname only (for connection pooling)"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Database port"
  value       = aws_db_instance.this.port
}

output "arn" {
  description = "Database ARN (for IAM policies)"
  value       = aws_db_instance.this.arn
}

output "connection_string" {
  description = "Full connection string (without password)"
  value       = "postgresql://dbadmin@${aws_db_instance.this.endpoint}/myapp"
  sensitive   = false  # 비밀번호는 포함하지 않음
}
```

### 5. 완벽한 README

```markdown
# CloudWatch Log Group Module

## 개요
KMS 암호화가 적용된 CloudWatch Log Group을 생성합니다.

## 사용 예시

### 기본 사용
\`\`\`hcl
module "app_logs" {
  source = "../../modules/cloudwatch-log-group"

  name              = "/aws/ecs/api-server/application"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
  common_tags       = module.common_tags.tags
}
\`\`\`

### 장기 보존 (1년)
\`\`\`hcl
module "audit_logs" {
  source = "../../modules/cloudwatch-log-group"

  name              = "/aws/audit/api-server"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs.arn
  common_tags       = module.common_tags.tags
}
\`\`\`

## 입력 변수

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Log group name | `string` | n/a | yes |
| retention_in_days | Log retention period | `number` | `30` | no |
| kms_key_id | KMS key ARN for encryption | `string` | n/a | yes |

## 출력 값

| Name | Description |
|------|-------------|
| log_group_name | CloudWatch log group name |
| log_group_arn | CloudWatch log group ARN |

## 거버넌스

- ✅ KMS 암호화 필수
- ✅ Retention 기간 검증 (CloudWatch 지원 값만 허용)
- ✅ 표준 태그 적용
```

## 🔄 State 관리 전략

### Backend 설정

```hcl
# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "yourcompany-prod-tfstate"
    key            = "services/api-server/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
    kms_key_id     = "alias/terraform-state"
  }
}
```

### State 격리 전략

```
terraform/
├── network/           # VPC, Subnet, Security Group
│   └── terraform.tfstate (독립적)
├── database/          # RDS, ElastiCache
│   └── terraform.tfstate (독립적)
├── services/
│   ├── api-server/    # ECS, ALB
│   │   └── terraform.tfstate (독립적)
│   └── worker/
│       └── terraform.tfstate (독립적)
└── security/          # KMS, Secrets Manager
    └── terraform.tfstate (독립적)
```

**장점:**
- ✅ Blast Radius 제한 (한 부분 오류가 전체 영향 안 줌)
- ✅ 병렬 작업 가능 (다른 팀원이 동시 작업)
- ✅ State Lock 충돌 감소

### 크로스 스택 참조: Output → SSM → Input

```hcl
# 1. network/ - VPC 정보를 SSM에 저장
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/prod/network/vpc-id"
  type  = "String"
  value = aws_vpc.main.id
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/prod/network/private-subnet-ids"
  type  = "StringList"
  value = join(",", aws_subnet.private[*].id)
}

# 2. services/api-server/ - SSM에서 VPC 정보 가져오기
data "aws_ssm_parameter" "vpc_id" {
  name = "/prod/network/vpc-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/prod/network/private-subnet-ids"
}

module "api_server_sg" {
  source = "../../modules/security-group"

  vpc_id = data.aws_ssm_parameter.vpc_id.value
  # ...
}

resource "aws_ecs_service" "api" {
  network_configuration {
    subnets = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  }
}
```

**장점:**
- ✅ State 파일 직접 참조 불필요 (독립성 유지)
- ✅ 환경별 분리 용이 (/dev, /staging, /prod)
- ✅ 순환 의존성 방지

## 🚀 다음 단계

이제 Terraform 모듈로 재사용 가능한 인프라 컴포넌트를 만드는 방법을 배웠습니다.

**다음 글에서 다룰 내용:**
1. **PR 기반 자동화 파이프라인** - GitHub Actions로 검증 자동화
2. **4단계 검증 시스템** - tfsec, checkov, OPA, Infracost 상세 가이드
3. **자동 PR 코멘트** - 검증 결과를 PR에 자동으로 표시

## 📚 참고 자료

- [Terraform 모듈 공식 가이드](https://www.terraform.io/docs/language/modules/)
- [Terraform Registry](https://registry.terraform.io/)
- [프로젝트의 모듈 디렉토리](../../terraform/modules/)

---

**이전 글:** [PR에서 인프라 관리하기 - Atlantis (2편)](./02-atlantis-pr-automation.md)
**다음 글:** [PR 기반 자동화 파이프라인 구축 (4편)](./04-automated-validation-pipeline.md)
