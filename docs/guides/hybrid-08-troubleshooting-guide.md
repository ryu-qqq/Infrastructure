# 하이브리드 인프라 트러블슈팅 가이드

**작성일**: 2025-10-22
**버전**: 1.0
**대상 독자**: 모든 팀 (문제 발생 시 참조)
**소요 시간**: 필요 시 참조

**선행 문서**:
- [Part 1: 개요 및 시작하기](hybrid-01-overview.md)
- [Part 2: 아키텍처 설계](hybrid-02-architecture-design.md)
- [Part 3: Infrastructure 프로젝트 설정](hybrid-03-infrastructure-setup.md)
- [Part 4: Application 프로젝트 설정](hybrid-04-application-setup.md)
- [Part 5: 배포 가이드](hybrid-05-deployment-guide.md)
- [Part 6: 모니터링 가이드](hybrid-06-monitoring-guide.md)
- [Part 7: 운영 가이드](hybrid-07-operations-guide.md)

---

## 목차

1. [일반적인 문제 및 해결 방법](#1-일반적인-문제-및-해결-방법)
   - [SSM Parameter를 찾을 수 없음](#ssm-parameter를-찾을-수-없음)
   - [Shared RDS 접근 권한 없음](#shared-rds-접근-권한-없음)
   - [KMS Key 권한 오류](#kms-key-권한-오류)
   - [Terraform State 잠금 오류](#terraform-state-잠금-오류)
   - [모듈을 찾을 수 없음](#모듈을-찾을-수-없음)
   - [Database 생성 스크립트 실패](#database-생성-스크립트-실패)

2. [모범 사례](#2-모범-사례)
   - [명명 규칙](#21-명명-규칙)
   - [보안](#22-보안)
   - [비용 최적화](#23-비용-최적화)
   - [유지보수성](#24-유지보수성)
   - [Git 워크플로](#25-git-워크플로)

3. [FAQ (자주 묻는 질문)](#3-faq-자주-묻는-질문)

4. [실제 프로젝트 구조](#4-실제-프로젝트-구조)

---

## 1. 일반적인 문제 및 해결 방법

### SSM Parameter를 찾을 수 없음

**증상**:
```
Error: error reading SSM Parameter (/shared/network/vpc-id): ParameterNotFound
```

**원인**: Infrastructure 프로젝트의 SSM Parameter가 생성되지 않음

**해결**:

```bash
# 1. Infrastructure 프로젝트로 이동
cd /path/to/infrastructure/terraform/network

# 2. Outputs에 SSM Parameter export가 있는지 확인
cat outputs.tf | grep aws_ssm_parameter

# 3. SSM Parameter가 없다면 추가 (이 가이드의 예제 참고)
# outputs.tf에 SSM Parameter 리소스 추가

# 4. Terraform 적용
terraform init
terraform apply

# 5. SSM Parameter 생성 확인
aws ssm get-parameter --name /shared/network/vpc-id
```

**예방**:
- Infrastructure 프로젝트의 `outputs.tf`에서 모든 SSM Parameter export를 확인
- Application 프로젝트 시작 전 SSM Parameter 목록 검증

---

### Shared RDS 접근 권한 없음

**증상**: ECS task에서 RDS 연결 실패

**원인**:
1. Security Group 규칙 누락
2. IAM 정책에 Secrets Manager 접근 권한 없음
3. KMS key 정책 문제

**해결**:

```bash
# 1. Security Group 규칙 확인
aws ec2 describe-security-group-rules \
  --filter "Name=group-id,Values=<rds-sg-id>"

# 2. ECS Task Security Group에서 RDS로 3306 포트 열기
# database.tf의 aws_security_group_rule 확인

# 3. IAM 정책 확인
aws iam get-role-policy \
  --role-name fileflow-dev-ecs-task-role \
  --policy-name fileflow-dev-db-access

# 4. Secrets Manager 접근 테스트 (ECS Exec)
aws secretsmanager get-secret-value \
  --secret-id <secret-arn> \
  --region ap-northeast-2
```

**체크리스트**:
- [ ] ECS Task Security Group → RDS Security Group (3306 포트)
- [ ] IAM Task Role → Secrets Manager 읽기 권한
- [ ] IAM Task Role → KMS Secrets Key 복호화 권한
- [ ] RDS Security Group → ECS Task Security Group 인바운드 허용

---

### KMS Key 권한 오류

**증상**:
```
Error: KMS.NotFoundException
Error: AccessDeniedException
```

**원인**: KMS key 정책에 서비스 principal 없음

**해결**:

```bash
# 1. KMS key ARN 확인
aws ssm get-parameter --name /shared/kms/s3-key-arn

# 2. KMS key 정책 확인
aws kms get-key-policy \
  --key-id <key-id> \
  --policy-name default

# 3. KMS key 정책에 서비스 principal 추가 (Infrastructure 프로젝트)
cd /path/to/infrastructure/terraform/kms

# main.tf의 KMS key 정책에 추가:
# - S3 key: s3.amazonaws.com
# - SQS key: sqs.amazonaws.com
# - ElastiCache key: elasticache.amazonaws.com

terraform apply
```

**올바른 KMS Key 정책 예제**:

```hcl
# kms/main.tf
resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow ECS Task Role to use the key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/fileflow-*-ecs-task-role"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}
```

---

### Terraform State 잠금 오류

**증상**:
```
Error: Error acquiring the state lock
```

**원인**: 다른 Terraform 프로세스가 실행 중이거나 비정상 종료

**해결**:

```bash
# 1. DynamoDB Lock 테이블 확인
aws dynamodb scan \
  --table-name terraform-lock \
  --region ap-northeast-2

# 2. Lock 강제 해제 (주의: 다른 프로세스 없는지 확인)
terraform force-unlock <lock-id>

# 3. Lock이 계속 발생하면 DynamoDB 테이블에서 직접 삭제
aws dynamodb delete-item \
  --table-name terraform-lock \
  --key '{"LockID": {"S": "<lock-id>"}}'
```

**예방**:
- Terraform 실행 전 다른 프로세스 확인
- CI/CD에서 동시 실행 방지 (concurrency 설정)
- Atlantis 사용 시 PR 단위 잠금 자동 관리

---

### 모듈을 찾을 수 없음

**증상**:
```
Error: Module not installed
```

**원인**: Infrastructure 프로젝트의 모듈이 복사되지 않음

**해결**:

```bash
# 1. Infrastructure 프로젝트에서 모듈 복사
cp -r /path/to/infrastructure/terraform/modules/{alb,ecs-service,elasticache,s3-bucket,sqs} \
      /path/to/{service-name}/infrastructure/terraform/modules/

# 2. Terraform 재초기화
cd /path/to/{service-name}/infrastructure/terraform
terraform init
```

**대안 - Git 모듈 참조**:

```hcl
module "storage_bucket" {
  source = "git::https://github.com/your-org/infrastructure.git//terraform/modules/s3-bucket?ref=v1.0.0"
  # ...
}
```

---

### Database 생성 스크립트 실패

**증상**:
```
Error: local-exec provisioner error
mysql: command not found
```

**원인**: mysql-client가 설치되지 않음

**해결**:

```bash
# macOS
brew install mysql-client

# Ubuntu/Debian
sudo apt-get install mysql-client

# Amazon Linux
sudo yum install mysql

# 환경 변수 추가 (macOS)
echo 'export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 설치 확인
mysql --version
```

---

## 2. 모범 사례

### 2.1 명명 규칙

#### SSM Parameter 경로

```
/shared/{category}/{resource-name}

예제:
/shared/network/vpc-id
/shared/kms/s3-key-arn
/shared/ecr/fileflow-repository-url
/shared/rds/prod/identifier
```

**규칙**:
- `shared` 프리픽스 사용 (공유 리소스)
- 카테고리로 그룹화 (network, kms, ecr, rds)
- kebab-case 사용
- 명확하고 설명적인 이름

---

#### Shared RDS 인스턴스

```
{environment}-shared-mysql

예제:
dev-shared-mysql
staging-shared-mysql
prod-shared-mysql
```

---

#### Database 이름

```
{service-name}

예제:
fileflow
authhub
crawler

# 짧고 명확하게 (특수문자 없이)
```

---

#### Database 사용자

```
{service-name}_user

예제:
fileflow_user
authhub_user
crawler_user
```

---

#### 리소스 네이밍

```
{service-name}-{environment}-{resource-type}

예제:
fileflow-prod-cluster
fileflow-prod-ecs-tasks-sg
fileflow-prod-storage-bucket
```

---

### 2.2 보안

#### Secrets 관리

- ✅ **Secrets Manager 사용**: 모든 민감 정보 (DB 패스워드, API 키)
- ✅ **KMS 암호화**: Secrets Manager에 KMS key 지정
- ❌ **하드코딩 금지**: Terraform 코드나 환경 변수에 패스워드 하드코딩 금지
- ✅ **최소 권한**: IAM 정책은 필요한 권한만 부여
- ✅ **Rotation**: Secrets Manager automatic rotation 활성화 (가능 시)

**올바른 예제**:

```hcl
# Secrets Manager에 저장
resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix             = "${local.name_prefix}-db-credentials-"
  kms_key_id              = local.secrets_key_arn
  recovery_window_in_days = 30
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    database = var.db_name
    host     = local.shared_rds_endpoint
    port     = 3306
  })
}
```

**잘못된 예제** (하드코딩):

```hcl
# ❌ 절대 이렇게 하지 마세요!
resource "aws_db_instance" "bad" {
  username = "admin"
  password = "MyPassword123!"  # 하드코딩 금지!
}
```

---

#### KMS Key 정책

- ✅ **리소스별 분리**: CloudWatch, S3, SQS, RDS 등 전용 키 사용
- ✅ **Key Rotation**: `enable_key_rotation = true`
- ✅ **Deletion Protection**: `deletion_window_in_days = 30` (prod)
- ✅ **Principal 명시**: 서비스별 principal 명확히 지정

---

#### Security Group

- ✅ **최소 권한**: 필요한 포트만 개방
- ✅ **소스 제한**: CIDR 대신 Security Group ID 참조
- ✅ **설명 추가**: 각 규칙에 `description` 추가
- ❌ **0.0.0.0/0 지양**: 불필요한 전역 개방 금지

**올바른 예제**:

```hcl
resource "aws_security_group_rule" "ecs_to_rds" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id  # SG ID 참조
  security_group_id        = data.aws_security_group.shared_rds.id
  description              = "Allow ECS tasks to connect to Shared RDS"
}
```

---

#### IAM 역할

- ✅ **최소 권한 원칙**: 필요한 권한만 부여
- ✅ **리소스 ARN 명시**: `"Resource": "*"` 지양
- ✅ **조건 추가**: 가능한 경우 `Condition` 블록 사용
- ✅ **역할 분리**: Execution Role과 Task Role 분리

**올바른 예제**:

```hcl
resource "aws_iam_role_policy" "task_policy" {
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn  # 특정 ARN 명시
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          local.secrets_key_arn  # 특정 KMS Key ARN
        ]
      }
    ]
  })
}
```

---

### 2.3 비용 최적화

#### Shared RDS 활용

- ✅ **멀티 테넌트**: 여러 서비스가 하나의 RDS 인스턴스 공유
- ✅ **적절한 인스턴스 크기**: 환경별 인스턴스 크기 조정
  - Dev: `db.t3.small`
  - Staging: `db.t3.medium`
  - Prod: `db.t3.large` ~ `db.r6g.xlarge`
- ✅ **Storage Auto Scaling**: `max_allocated_storage` 설정
- ❌ **과도한 백업 보관 지양**: 백업 보관 기간 적절히 설정 (7일)

---

#### ECS Auto Scaling

- ✅ **Target Tracking**: CPU/Memory 기반 Auto Scaling
- ✅ **환경별 범위**: Dev는 1~3, Prod는 2~10
- ✅ **Scale-in 보호**: Prod 환경에서 최소 태스크 수 유지

```hcl
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.environment == "prod" ? 10 : 3
  min_capacity       = var.environment == "prod" ? 2 : 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${local.name_prefix}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
```

---

#### S3 Lifecycle

- ✅ **Lifecycle Rules**: 오래된 파일 자동 아카이빙
  - 90일: Standard → Standard-IA
  - 365일: Standard-IA → Glacier
  - 7년: Glacier → Expiration
- ✅ **Intelligent Tiering**: 액세스 패턴에 따라 자동 이동

---

#### CloudWatch Logs

- ✅ **보존 기간 설정**: 7~14일 (환경별)
- ✅ **S3 Export**: 장기 보관이 필요한 로그는 S3로 Export
- ❌ **무제한 보관 지양**: 비용 증가 원인

---

### 2.4 유지보수성

#### 일관된 디렉토리 구조

```
{service-name}/infrastructure/terraform/
├── environments/
│   ├── dev/terraform.tfvars
│   ├── staging/terraform.tfvars
│   └── prod/terraform.tfvars
├── modules/
├── data.tf
├── locals.tf
├── variables.tf
├── provider.tf
├── database.tf
├── ecs.tf
├── redis.tf
├── s3.tf
├── sqs.tf
├── alb.tf
├── iam.tf
└── outputs.tf
```

---

#### 주석 작성

```hcl
# ============================================================================
# Database Configuration (Shared RDS)
# ============================================================================
# This configuration connects to the shared RDS instance and creates
# a service-specific database and user with limited privileges.
#
# Privileges granted:
# - SELECT, INSERT, UPDATE, DELETE (DML)
# - CREATE, DROP, INDEX, ALTER (DDL)
#
# Security:
# - Credentials stored in Secrets Manager
# - KMS encryption enabled
# - Security group restricts access to ECS tasks only
# ============================================================================

resource "aws_security_group_rule" "shared_rds_from_ecs" {
  # ...
}
```

---

#### 모듈화

- ✅ **재사용 가능한 모듈**: 공통 패턴 모듈화
- ✅ **버전 관리**: 모듈 버전 명시 (`version = "1.0.0"`)
- ✅ **문서화**: 각 모듈에 `README.md` 추가
- ✅ **예제 제공**: `examples/` 디렉토리에 사용 예제

---

#### 문서화

- ✅ **README.md**: 프로젝트 개요, 배포 방법
- ✅ **CHANGELOG.md**: 버전별 변경 사항
- ✅ **아키텍처 다이어그램**: ASCII art 또는 이미지
- ✅ **트러블슈팅 가이드**: 자주 발생하는 문제 해결 방법

---

### 2.5 Git 워크플로

#### 브랜치 전략

```
main (production)
├── develop (staging)
│   ├── feature/KAN-XXX-description
│   └── hotfix/KAN-YYY-description
```

---

#### 커밋 메시지

```bash
# 형식
feat: Add Shared RDS connection (KAN-153)
fix: Correct KMS key reference in S3 module (KAN-155)
docs: Update hybrid infrastructure guide

# 예제
feat: Add FileFlow database.tf with shared RDS connection
- Security group rule for ECS → RDS
- Database and user creation with null_resource
- IAM policy for database credentials access

fix: Use local.secrets_key_arn instead of remote state in iam.tf
- Removed data.terraform_remote_state.kms
- Updated all KMS key references to use locals

docs: Add troubleshooting section for SSM Parameter errors
- Steps to verify SSM Parameters
- How to recreate missing parameters
```

---

#### Pull Request 체크리스트

- [ ] `terraform fmt -recursive` 실행
- [ ] `terraform validate` 통과
- [ ] `terraform plan` 검토 완료
- [ ] 보안 스캔 통과 (tfsec, checkov)
- [ ] 주석 및 문서 업데이트
- [ ] 관련 Jira 태스크 링크

---

## 3. FAQ (자주 묻는 질문)

### Q1: 언제 Shared RDS를 사용하고 언제 전용 RDS를 사용해야 하나요?

**A**: 다음 기준으로 판단하세요.

**Shared RDS 사용 (권장)**:
- ✅ 초기 단계 서비스 (MVP)
- ✅ 트래픽이 낮거나 중간 수준
- ✅ 데이터베이스 격리가 필수가 아님
- ✅ 비용 절감이 중요
- ✅ 여러 마이크로서비스 통합 관리

**전용 RDS 사용**:
- ❌ 대규모 트래픽 (>10,000 QPS)
- ❌ 특수한 RDS 설정 필요 (Parameter Group, Engine Version)
- ❌ 완전한 데이터 격리 필요 (보안/규정 준수)
- ❌ 독립적인 확장 필요
- ❌ 다른 서비스와 성능 격리 필요

**마이그레이션 경로**:
초기에는 Shared RDS로 시작 → 트래픽 증가 시 전용 RDS로 마이그레이션

---

### Q2: SSM Parameter vs Terraform Remote State, 어떤 것을 사용해야 하나요?

**A**: 하이브리드 구조에서는 **SSM Parameter 권장**.

| 기준 | SSM Parameter | Terraform Remote State |
|-----|--------------|----------------------|
| **런타임 참조** | ✅ 가능 (애플리케이션에서 직접 조회) | ❌ 불가능 |
| **AWS 서비스 통합** | ✅ 네이티브 통합 | ❌ Terraform에서만 |
| **버전 관리** | ✅ 자동 버전 관리 | ❌ State 파일 의존 |
| **암호화** | ✅ KMS 암호화 지원 | ⚠️ S3 백엔드 암호화만 |
| **Terraform 의존성** | ✅ 의존성 없음 (단방향) | ❌ 양방향 의존성 (복잡도 증가) |
| **변경 전파** | ✅ 즉시 반영 | ❌ State refresh 필요 |

**SSM Parameter 예제**:

```hcl
# Infrastructure 프로젝트 (Export)
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/shared/network/vpc-id"
  value = aws_vpc.main.id
}

# Application 프로젝트 (Import)
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
}
```

---

### Q3: 여러 환경(dev/staging/prod)을 어떻게 관리하나요?

**A**: 환경별 tfvars 파일 + 환경별 Shared RDS 인스턴스 사용.

**디렉토리 구조**:

```
infrastructure/terraform/
├── environments/
│   ├── dev/terraform.tfvars
│   ├── staging/terraform.tfvars
│   └── prod/terraform.tfvars
└── (공통 .tf 파일)
```

**환경별 Shared RDS 인스턴스**:

```
dev-shared-mysql        ← Dev 환경 서비스들 공유
staging-shared-mysql    ← Staging 환경 서비스들 공유
prod-shared-mysql       ← Prod 환경 서비스들 공유
```

**환경별 배포**:

```bash
# Dev 배포
terraform apply -var-file=environments/dev/terraform.tfvars

# Staging 배포
terraform apply -var-file=environments/staging/terraform.tfvars

# Prod 배포
terraform apply -var-file=environments/prod/terraform.tfvars
```

**환경별 리소스 크기**:

| 리소스 | Dev | Staging | Prod |
|--------|-----|---------|------|
| **ECS Task** | 512 CPU / 1GB RAM | 1024 CPU / 2GB RAM | 2048 CPU / 4GB RAM |
| **RDS** | db.t3.small | db.t3.medium | db.t3.large |
| **Redis** | cache.t3.micro | cache.t3.small | cache.t3.medium |
| **ECS Desired Count** | 1 | 2 | 3 |

---

### Q4: 기존 전용 RDS를 Shared RDS로 마이그레이션하려면?

**A**: 다음 단계를 따르세요.

**1. 데이터 백업**

```bash
# RDS 스냅샷 생성
aws rds create-db-snapshot \
  --db-instance-identifier fileflow-prod-db \
  --db-snapshot-identifier fileflow-prod-db-pre-migration-$(date +%Y%m%d)

# 또는 mysqldump
mysqldump -h <old-rds-endpoint> -u admin -p \
  --databases fileflow \
  --single-transaction \
  --routines \
  --triggers \
  > fileflow_backup_$(date +%Y%m%d).sql
```

**2. Shared RDS에 database 및 user 생성**

```sql
-- Shared RDS에 연결
mysql -h prod-shared-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com -u admin -p

-- Database 생성
CREATE DATABASE IF NOT EXISTS fileflow
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- User 생성
CREATE USER IF NOT EXISTS 'fileflow_user'@'%'
  IDENTIFIED BY '<password>';

-- 권한 부여
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
  ON fileflow.* TO 'fileflow_user'@'%';

FLUSH PRIVILEGES;
```

**3. 데이터 마이그레이션**

```bash
# mysqldump로 백업한 경우
mysql -h prod-shared-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com \
  -u fileflow_user -p fileflow < fileflow_backup_20251021.sql

# 또는 AWS DMS 사용 (대용량 데이터)
# https://aws.amazon.com/dms/
```

**4. 애플리케이션 연결 문자열 업데이트**

Terraform `database.tf` 수정:

```hcl
# 기존 전용 RDS (제거)
# resource "aws_db_instance" "fileflow" { ... }

# Shared RDS 연결 (추가)
data "aws_db_instance" "shared" {
  db_instance_identifier = var.shared_rds_identifier
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = "fileflow_user"
    password = random_password.db_password.result
    database = "fileflow"
    host     = data.aws_db_instance.shared.endpoint  # ← Shared RDS endpoint
    port     = 3306
  })
}
```

**5. 검증**

```bash
# ECS task에서 새 RDS 연결 확인
aws ecs execute-command \
  --cluster fileflow-prod-cluster \
  --task <task-id> \
  --container fileflow \
  --command "/bin/sh" \
  --interactive

# Container 내부에서
mysql -h prod-shared-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com \
  -u fileflow_user -p

# 데이터 확인
USE fileflow;
SHOW TABLES;
SELECT COUNT(*) FROM <table-name>;
```

**6. 전용 RDS 제거**

검증 완료 후:

```bash
# 1. 최종 스냅샷 생성
aws rds create-db-snapshot \
  --db-instance-identifier fileflow-prod-db \
  --db-snapshot-identifier fileflow-prod-db-final-$(date +%Y%m%d)

# 2. RDS 인스턴스 삭제
terraform destroy -target=aws_db_instance.fileflow
```

---

### Q5: SSM Parameter가 변경되면 Application Terraform에 어떻게 반영되나요?

**A**: SSM Parameter 변경 시 Application Terraform `plan`에서 자동 감지됩니다.

**시나리오**: VPC ID가 변경된 경우

```bash
# Infrastructure 프로젝트에서 VPC 재생성
cd /path/to/infrastructure/terraform/network
terraform apply
# 새로운 VPC ID: vpc-new123
# SSM Parameter /shared/network/vpc-id 자동 업데이트

# Application 프로젝트에서 Plan 실행
cd /path/to/fileflow/infrastructure/terraform
terraform plan

# 출력:
# ~ resource "aws_security_group" "ecs_tasks" {
#     ~ vpc_id = "vpc-old456" -> "vpc-new123" (forces replacement)
#   }
```

**중요**: SSM Parameter 변경은 Application 리소스 재생성을 유발할 수 있으므로, 신중하게 계획해야 합니다.

---

### Q6: 하나의 Application 프로젝트에서 여러 서비스를 관리할 수 있나요?

**A**: 가능하지만 권장하지 않습니다.

**권장하지 않는 이유**:
- ❌ 서비스별 독립적 배포 불가
- ❌ Terraform state 복잡도 증가
- ❌ 변경 영향 범위 불명확
- ❌ 팀 간 코드 충돌 가능성

**권장 구조** (서비스별 분리):

```
fileflow/infrastructure/terraform/     ← FileFlow 서비스만
authhub/infrastructure/terraform/      ← AuthHub 서비스만
crawler/infrastructure/terraform/      ← Crawler 서비스만
```

**예외** (모노레포 구조가 필요한 경우):
- Workspace를 사용하여 서비스별 state 분리
- 디렉토리 구조로 서비스 분리

```
infrastructure/
├── services/
│   ├── fileflow/
│   │   ├── main.tf
│   │   └── ...
│   ├── authhub/
│   │   ├── main.tf
│   │   └── ...
│   └── crawler/
│       ├── main.tf
│       └── ...
```

---

### Q7: Terraform Module을 Infrastructure 프로젝트에서 참조하려면?

**A**: 두 가지 방법이 있습니다.

**방법 1: 모듈 복사** (권장)

```bash
# Infrastructure 프로젝트에서 Application 프로젝트로 복사
cp -r /path/to/infrastructure/terraform/modules/{alb,ecs-service,elasticache,s3-bucket,sqs} \
      /path/to/fileflow/infrastructure/terraform/modules/

# Application Terraform에서 사용
module "storage_bucket" {
  source = "../modules/s3-bucket"
  # ...
}
```

**장점**:
- ✅ 독립적 버전 관리
- ✅ Infrastructure 프로젝트 변경에 영향 없음
- ✅ 배포 속도 빠름

**단점**:
- ❌ 모듈 중복
- ❌ 업데이트 수동 동기화 필요

**방법 2: Git 모듈 참조**

```hcl
module "storage_bucket" {
  source = "git::https://github.com/your-org/infrastructure.git//terraform/modules/s3-bucket?ref=v1.0.0"
  # ...
}
```

**장점**:
- ✅ 모듈 중복 없음
- ✅ 버전 관리 명확

**단점**:
- ❌ 네트워크 의존성
- ❌ 배포 속도 느림
- ❌ Private repository 접근 권한 필요

---

## 4. 실제 프로젝트 구조

### Infrastructure 프로젝트

**위치**: `/path/to/infrastructure/terraform/`

```
infrastructure/terraform/
├── network/                    # VPC, Subnets (중앙 관리)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf             # SSM Parameter exports
│   ├── locals.tf
│   └── provider.tf
│
├── kms/                        # KMS Keys (중앙 관리)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf             # SSM Parameter exports
│   ├── locals.tf
│   └── provider.tf
│
├── rds/                        # Shared RDS (중앙 관리)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── locals.tf
│   ├── database-parameter-group.tf
│   └── provider.tf
│
├── ecr/                        # ECR Repositories (서비스별)
│   ├── fileflow/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf        # SSM Parameter exports
│   │   ├── locals.tf
│   │   ├── data.tf
│   │   └── provider.tf
│   ├── authhub/
│   └── crawler/
│
├── shared/                     # 공유 리소스 모듈
│   ├── kms/
│   ├── network/
│   └── security/
│
├── modules/                    # 재사용 가능한 모듈
│   ├── alb/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── cloudwatch-log-group/
│   ├── common-tags/
│   ├── ecs-service/
│   ├── elasticache/
│   ├── iam-role-policy/
│   ├── rds/
│   ├── s3-bucket/
│   ├── security-group/
│   └── sqs/
│
├── monitoring/                 # 중앙 모니터링
│   ├── cloudwatch-dashboards.tf
│   ├── sns-topics.tf
│   └── prometheus.tf
│
├── cloudtrail/                 # 감사 로그
│   ├── main.tf
│   └── s3-bucket.tf
│
├── atlantis/                   # Atlantis 서버 (자체 관리)
│   ├── ecs.tf
│   ├── alb.tf
│   └── iam.tf
│
└── bootstrap/                  # 초기 설정
    ├── s3-backend.tf
    ├── dynamodb-lock.tf
    └── kms.tf
```

---

### Application 프로젝트 (예: FileFlow)

**위치**: `/path/to/fileflow/infrastructure/terraform/`

```
fileflow/
├── application/                # 애플리케이션 코드
│   ├── src/
│   ├── tests/
│   ├── Dockerfile
│   └── package.json
│
└── infrastructure/             # 인프라 코드
    └── terraform/
        ├── environments/       # 환경별 설정
        │   ├── dev/
        │   │   └── terraform.tfvars
        │   ├── staging/
        │   │   └── terraform.tfvars
        │   └── prod/
        │       └── terraform.tfvars
        │
        ├── modules/            # 프로젝트 전용 모듈 (옵션)
        │   └── (Infrastructure 모듈 복사 또는 참조)
        │
        ├── provider.tf         # AWS Provider, Backend 설정
        ├── data.tf             # SSM Parameters 데이터 소스
        ├── locals.tf           # SSM Parameter 값 → 로컬 변수
        ├── variables.tf        # 입력 변수
        │
        ├── ecs.tf              # ECS Cluster, Service, Task Definition
        ├── database.tf         # Shared RDS 연결, Database 생성
        ├── redis.tf            # ElastiCache Redis
        ├── s3.tf               # S3 Buckets
        ├── sqs.tf              # SQS Queues
        ├── alb.tf              # Application Load Balancer
        ├── iam.tf              # IAM Roles and Policies
        ├── security-groups.tf  # Security Groups
        │
        ├── cloudwatch-logs.tf  # CloudWatch Log Groups
        ├── cloudwatch-alarms.tf # CloudWatch Alarms
        ├── application-insights.tf # Application Insights
        │
        ├── outputs.tf          # Output 값
        └── README.md           # 프로젝트별 가이드
```

---

### 실제 디렉토리 구조 (Tree 형태)

#### Infrastructure 프로젝트

```bash
infrastructure/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml
│       ├── terraform-apply.yml
│       ├── terraform-apply-and-deploy.yml
│       └── infra-checks.yml
│
├── .claude/
│   ├── settings.local.json
│   └── INFRASTRUCTURE_RULES.md
│
├── terraform/
│   ├── acm/                    # SSL/TLS 인증서
│   ├── atlantis/               # Atlantis ECS 서버
│   ├── bootstrap/              # S3 Backend, DynamoDB Lock
│   ├── cloudtrail/             # CloudTrail 감사 로그
│   ├── ecr/                    # ECR 레포지토리
│   │   └── fileflow/
│   ├── kms/                    # KMS 키 (7개)
│   ├── logging/                # 중앙 로깅
│   ├── modules/                # 재사용 모듈 (10개)
│   │   ├── alb/
│   │   ├── cloudwatch-log-group/
│   │   ├── common-tags/
│   │   ├── ecs-service/
│   │   ├── elasticache/
│   │   ├── iam-role-policy/
│   │   ├── rds/
│   │   ├── s3-bucket/
│   │   ├── security-group/
│   │   └── sqs/
│   ├── monitoring/             # CloudWatch, Prometheus
│   ├── network/                # VPC, Subnets
│   ├── rds/                    # Shared RDS
│   ├── route53/                # DNS
│   ├── secrets/                # Secrets Manager
│   ├── shared/                 # 공유 리소스
│   │   ├── kms/
│   │   ├── network/
│   │   └── security/
│   └── test/                   # 테스트 모듈
│
├── scripts/
│   ├── validators/             # Terraform 검증 스크립트
│   │   ├── check-tags.sh
│   │   ├── check-encryption.sh
│   │   ├── check-naming.sh
│   │   ├── check-tfsec.sh
│   │   ├── check-checkov.sh
│   │   └── validate-terraform-file.sh
│   ├── setup-hooks.sh
│   ├── build-and-push.sh      # Docker 빌드 및 ECR Push
│   ├── atlantis/
│   │   ├── check-atlantis-health.sh
│   │   ├── monitor-atlantis-logs.sh
│   │   └── restart-atlantis.sh
│   └── export-logs-to-s3.sh
│
├── docs/
│   ├── governance/
│   │   ├── tagging-standards.md
│   │   ├── encryption-policy.md
│   │   └── naming-conventions.md
│   ├── guides/
│   │   ├── hybrid-01-overview.md
│   │   ├── hybrid-02-architecture-design.md
│   │   ├── hybrid-03-infrastructure-setup.md
│   │   ├── hybrid-04-application-setup.md
│   │   ├── hybrid-05-deployment-guide.md
│   │   ├── hybrid-06-monitoring-guide.md
│   │   ├── hybrid-07-operations-guide.md
│   │   ├── hybrid-08-troubleshooting-guide.md  # 이 문서
│   │   ├── cloudtrail-operations-guide.md
│   │   └── atlantis-setup-guide.md
│   └── modules/
│       └── module-development-guide.md
│
├── policies/                   # OPA 정책
│   ├── required-tags.rego
│   ├── encryption.rego
│   └── naming.rego
│
├── CLAUDE.md                   # Claude Code 가이드
├── README.md                   # 프로젝트 개요
├── .tfsec/
│   └── config.yml
├── .checkov.yml
└── atlantis.yaml
```

---

#### Application 프로젝트 (FileFlow)

**참고**: FileFlow 프로젝트는 별도 Repository에 있으며, 실제 경로는 다를 수 있습니다.

```bash
fileflow/
├── application/
│   ├── src/
│   ├── tests/
│   ├── Dockerfile
│   ├── package.json
│   └── README.md
│
├── infrastructure/
│   └── terraform/
│       ├── environments/
│       │   ├── dev/
│       │   │   └── terraform.tfvars
│       │   ├── staging/
│       │   │   └── terraform.tfvars
│       │   └── prod/
│       │       └── terraform.tfvars
│       │
│       ├── provider.tf
│       ├── data.tf
│       ├── locals.tf
│       ├── variables.tf
│       ├── ecs.tf
│       ├── database.tf
│       ├── redis.tf
│       ├── s3.tf
│       ├── sqs.tf
│       ├── alb.tf
│       ├── iam.tf
│       ├── security-groups.tf
│       ├── cloudwatch-logs.tf
│       ├── cloudwatch-alarms.tf
│       ├── application-insights.tf
│       ├── outputs.tf
│       └── README.md
│
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml
│       ├── deploy.yml
│       └── ci.yml
│
└── README.md
```

---

### 주요 파일 설명

#### Infrastructure 프로젝트

| 파일/디렉토리 | 설명 | 중요도 |
|--------------|------|--------|
| `terraform/network/` | VPC, Subnets, Route Tables | ⭐⭐⭐⭐⭐ |
| `terraform/kms/` | 7개 KMS 키 (데이터 암호화) | ⭐⭐⭐⭐⭐ |
| `terraform/rds/` | Shared RDS (공유 데이터베이스) | ⭐⭐⭐⭐⭐ |
| `terraform/ecr/fileflow/` | FileFlow ECR 레포지토리 | ⭐⭐⭐⭐ |
| `terraform/modules/` | 재사용 가능한 모듈 (10개) | ⭐⭐⭐⭐ |
| `.github/workflows/` | CI/CD 파이프라인 | ⭐⭐⭐⭐ |
| `scripts/validators/` | Governance 검증 스크립트 | ⭐⭐⭐ |
| `docs/guides/` | 운영 가이드 문서 | ⭐⭐⭐ |
| `terraform/atlantis/` | Atlantis 서버 (Terraform 자동화) | ⭐⭐⭐ |
| `terraform/monitoring/` | 중앙 모니터링 (CloudWatch, Prometheus) | ⭐⭐⭐ |

---

#### Application 프로젝트

| 파일 | 설명 | 중요도 |
|------|------|--------|
| `terraform/data.tf` | SSM Parameters 데이터 소스 | ⭐⭐⭐⭐⭐ |
| `terraform/locals.tf` | SSM 값 → 로컬 변수 매핑 | ⭐⭐⭐⭐⭐ |
| `terraform/database.tf` | Shared RDS 연결 | ⭐⭐⭐⭐ |
| `terraform/ecs.tf` | ECS Cluster, Service, Task | ⭐⭐⭐⭐ |
| `terraform/iam.tf` | IAM Roles and Policies | ⭐⭐⭐⭐ |
| `environments/*/terraform.tfvars` | 환경별 설정 값 | ⭐⭐⭐⭐ |
| `terraform/cloudwatch-alarms.tf` | 알람 설정 | ⭐⭐⭐ |

---

## 완료!

✅ **8개 가이드 문서 전체 완료!**

하이브리드 인프라 가이드 시리즈:
1. ✅ [개요 및 시작하기](hybrid-01-overview.md)
2. ✅ [아키텍처 설계](hybrid-02-architecture-design.md)
3. ✅ [Infrastructure 프로젝트 설정](hybrid-03-infrastructure-setup.md)
4. ✅ [Application 프로젝트 설정](hybrid-04-application-setup.md)
5. ✅ [배포 가이드](hybrid-05-deployment-guide.md)
6. ✅ [모니터링 가이드](hybrid-06-monitoring-guide.md)
7. ✅ [운영 가이드](hybrid-07-operations-guide.md)
8. ✅ **트러블슈팅 가이드** (이 문서)

**다음 단계**:
- [메인 가이드로 돌아가기](hybrid-infrastructure-guide.md)
- 특정 문제 발생 시 이 문서의 해당 섹션 참조
- 추가 질문은 Slack #platform-support 채널로 문의

---

## 참고 자료

### 관련 문서
- [하이브리드 인프라 가이드 메인](hybrid-infrastructure-guide.md)
- [Infrastructure 프로젝트 README](/terraform/shared/README.md)
- [모듈 개발 가이드](/docs/modules/MODULE_DEVELOPMENT_GUIDE.md)

### Terraform 모듈
- [공통 모듈](/terraform/modules/)
- [모듈 개발 가이드](/docs/modules/)

### 실제 구현 예제
- [FileFlow 프로젝트](/path/to/fileflow/infrastructure/terraform/)

### AWS 공식 문서
- [SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [KMS](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)
- [RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html)
- [ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html)

### Terraform 공식 문서
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Data Sources](https://www.terraform.io/language/data-sources)
- [Modules](https://www.terraform.io/language/modules)

---

**Last Updated**: 2025-10-22
**Version**: 1.0
