# 1️⃣ 개요 및 시작하기

**하이브리드 Terraform 인프라 구조 가이드 - Part 1**

**작성일**: 2025-10-22
**버전**: 2.0
**대상 독자**: DevOps 엔지니어, 플랫폼 팀, 새로운 서비스를 론칭하는 개발팀

---

## 📋 이 가이드에서 다루는 내용

1. [하이브리드 인프라 구조란?](#하이브리드-인프라-구조란)
2. [빠른 시작 가이드](#빠른-시작-가이드)
3. [기술 스택 및 버전 요구사항](#기술-스택-및-버전-요구사항)
4. [사전 요구사항](#사전-요구사항)

---

## 하이브리드 인프라 구조란?

하이브리드 인프라 구조는 **중앙 집중식 관리**와 **프로젝트별 분산 관리**를 결합한 인프라 관리 방식입니다.

```
Infrastructure Repository          Application Repository
┌─────────────────────┐           ┌──────────────────────┐
│ 공유 인프라 (중앙)   │           │ 애플리케이션 인프라   │
│ - VPC, Subnets      │───────────│ - ECS, Task Def      │
│ - KMS Keys          │   SSM     │ - S3, SQS, Redis     │
│ - Shared RDS        │  Parameters│ - ALB, Auto Scaling  │
│ - ECR Repository    │           │ - Database Schema    │
└─────────────────────┘           └──────────────────────┘
```

### 왜 이 구조를 사용하는가?

#### 단일 Repository 방식 (Not Recommended)

```
infrastructure/
├── network/
├── kms/
├── service-a/
├── service-b/
└── service-c/
```

**단점**:
- 서비스별 배포 독립성 부족
- 인프라 변경이 모든 서비스에 영향
- 코드 충돌 및 Merge 복잡도 증가
- 애플리케이션 코드와 인프라 분리 불가

#### 멀티 Repository 방식 (Isolated)

```
service-a/infrastructure/  (모든 인프라 포함)
service-b/infrastructure/  (모든 인프라 포함)
service-c/infrastructure/  (모든 인프라 포함)
```

**단점**:
- VPC, KMS 등 공유 리소스 중복 생성
- 일관성 유지 어려움
- 비용 증가 (리소스 중복)
- 네트워크 복잡도 증가 (VPC Peering 필요)

#### 하이브리드 방식 (Recommended) ✅

```
infrastructure/            ← 공유 인프라 중앙 관리
service-a/infrastructure/  ← 서비스별 인프라
service-b/infrastructure/  ← 서비스별 인프라
service-c/infrastructure/  ← 서비스별 인프라
```

**장점**:
- ✅ 공유 리소스 중앙 관리 (VPC, KMS, 네트워크)
- ✅ 서비스별 독립적 배포 가능
- ✅ 애플리케이션 코드와 인프라 동기화
- ✅ 비용 절감 (공유 리소스 활용)
- ✅ 일관성 유지 (중앙 거버넌스)

### 적용 대상 프로젝트

#### 이 방식을 사용해야 하는 경우

- ✅ 마이크로서비스 아키텍처
- ✅ 여러 서비스가 동일한 네트워크 공유
- ✅ 서비스별 독립적 배포 필요
- ✅ 애플리케이션 코드와 인프라 동기화 필요
- ✅ Shared RDS 사용 (멀티 테넌트 데이터베이스)

#### 전용 인프라를 사용해야 하는 경우

- ❌ 단일 모놀리식 애플리케이션
- ❌ 완전히 격리된 환경 필요 (보안/규정 준수)
- ❌ 트래픽이 매우 높아 전용 RDS 필요
- ❌ 특수한 네트워크 구성 필요

---

## 빠른 시작 가이드

### 🚀 초기 설정 체크리스트

새로운 서비스를 위한 하이브리드 인프라를 구축할 때 다음 단계를 순서대로 진행하세요.

#### Phase 1: Infrastructure 프로젝트 준비 (중앙 관리)

**목표**: 공유 인프라 리소스가 배포되어 있고 SSM Parameters로 Export되었는지 확인

- [ ] **1.1 Network 모듈 배포 확인**
  ```bash
  cd /Users/sangwon-ryu/infrastructure/terraform/network
  terraform init
  terraform plan
  terraform apply
  ```
  - VPC, Subnets, Route Tables 생성 확인
  - SSM Parameters 생성 확인: `/shared/network/*`

- [ ] **1.2 KMS 모듈 배포 확인**
  ```bash
  cd /Users/sangwon-ryu/infrastructure/terraform/kms
  terraform init
  terraform plan
  terraform apply
  ```
  - 7개 KMS 키 생성 확인 (cloudwatch-logs, secrets-manager, rds, s3, sqs, ssm, elasticache)
  - SSM Parameters 생성 확인: `/shared/kms/*`

- [ ] **1.3 ECR 레포지토리 생성**
  ```bash
  cd /Users/sangwon-ryu/infrastructure/terraform/ecr/[service-name]
  # 예: cd /Users/sangwon-ryu/infrastructure/terraform/ecr/fileflow
  terraform init
  terraform plan
  terraform apply
  ```
  - ECR 레포지토리 생성 확인
  - Lifecycle Policy 설정 확인
  - SSM Parameter 생성 확인: `/shared/ecr/[service-name]-repository-url`

- [ ] **1.4 Shared RDS 배포 (옵션, 필요시)**
  ```bash
  cd /Users/sangwon-ryu/infrastructure/terraform/rds
  terraform init
  terraform plan
  terraform apply
  ```
  - Multi-AZ RDS 인스턴스 생성 확인
  - Master credentials가 Secrets Manager에 저장되었는지 확인

#### Phase 2: SSM Parameters 검증

**목표**: 모든 필수 SSM Parameters가 생성되었는지 확인

- [ ] **2.1 필수 SSM Parameters 확인 (총 13개)**
  ```bash
  # 모든 공유 파라미터 조회
  aws ssm get-parameters-by-path \
    --path /shared \
    --recursive \
    --region ap-northeast-2 \
    --query 'Parameters[*].[Name,Value]' \
    --output table
  ```

  **필수 Parameters 목록**:
  - `/shared/network/vpc-id`
  - `/shared/network/public-subnet-ids`
  - `/shared/network/private-subnet-ids`
  - `/shared/network/data-subnet-ids`
  - `/shared/kms/cloudwatch-logs-key-arn`
  - `/shared/kms/secrets-manager-key-arn`
  - `/shared/kms/rds-key-arn`
  - `/shared/kms/s3-key-arn`
  - `/shared/kms/sqs-key-arn`
  - `/shared/kms/ssm-key-arn`
  - `/shared/kms/elasticache-key-arn`
  - `/shared/ecr/[service-name]-repository-url`
  - (옵션) `/shared/rds/[env]/endpoint`

- [ ] **2.2 개별 Parameter 확인**
  ```bash
  # VPC ID 확인
  aws ssm get-parameter --name /shared/network/vpc-id --region ap-northeast-2

  # KMS 키 ARN 확인
  aws ssm get-parameter --name /shared/kms/cloudwatch-logs-key-arn --region ap-northeast-2

  # ECR URL 확인
  aws ssm get-parameter --name /shared/ecr/fileflow-repository-url --region ap-northeast-2
  ```

#### Phase 3: Application 프로젝트 설정

**목표**: 새로운 서비스의 인프라 코드 작성 및 초기 배포

- [ ] **3.1 디렉토리 구조 생성**
  ```bash
  # 서비스 디렉토리 생성 (예: fileflow)
  mkdir -p /Users/sangwon-ryu/fileflow/infrastructure/terraform
  cd /Users/sangwon-ryu/fileflow/infrastructure/terraform

  # 환경별 tfvars 디렉토리 생성
  mkdir -p environments/{dev,staging,prod}

  # 모듈 디렉토리 생성 (필요시)
  mkdir -p modules
  ```

- [ ] **3.2 환경별 tfvars 파일 생성**

  **파일**: `environments/dev/terraform.tfvars`
  ```hcl
  # 환경 설정
  env         = "dev"
  aws_region  = "ap-northeast-2"

  # 서비스 정보
  service     = "fileflow"
  team        = "platform-team"
  owner       = "platform@ryuqqq.com"
  cost_center = "engineering"

  # ECS 설정
  ecs_task_cpu    = 512
  ecs_task_memory = 1024
  desired_count   = 1
  min_capacity    = 1
  max_capacity    = 3

  # Database 설정 (Shared RDS 사용)
  database_name = "fileflow"
  database_user = "fileflow_user"

  # Redis 설정
  redis_node_type       = "cache.t3.micro"
  redis_num_cache_nodes = 1
  ```

- [ ] **3.3 핵심 Terraform 파일 작성**
  - `provider.tf`: AWS Provider 및 Backend 설정
  - `data.tf`: SSM Parameters 데이터 소스
  - `locals.tf`: SSM Parameter 값을 로컬 변수로 매핑
  - `variables.tf`: 입력 변수 정의
  - `ecs.tf`: ECS Cluster, Service, Task Definition
  - `database.tf`: Shared RDS 연결 및 Database 생성
  - `redis.tf`: ElastiCache Redis
  - `s3.tf`: S3 Buckets
  - `sqs.tf`: SQS Queues
  - `alb.tf`: Application Load Balancer
  - `iam.tf`: IAM Roles and Policies
  - `outputs.tf`: Output 값 정의

- [ ] **3.4 Shared RDS Database 및 User 생성**

  **방법 1: Terraform null_resource (권장)**
  ```hcl
  # database.tf
  resource "null_resource" "create_database" {
    provisioner "local-exec" {
      command = <<-EOT
        mysql -h ${local.shared_rds_endpoint} \
              -u ${local.shared_rds_master_username} \
              -p${local.shared_rds_master_password} \
              -e "CREATE DATABASE IF NOT EXISTS ${var.database_name}..."
      EOT
    }
  }
  ```

  **방법 2: 수동 실행**
  ```bash
  # Shared RDS Master credentials 조회
  aws secretsmanager get-secret-value \
    --secret-id prod-shared-mysql-master-credentials \
    --region ap-northeast-2 \
    --query SecretString --output text | jq -r '.password'

  # MySQL 접속 및 Database 생성
  mysql -h prod-shared-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com -u admin -p

  CREATE DATABASE IF NOT EXISTS fileflow CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS 'fileflow_user'@'%' IDENTIFIED BY '<password>';
  GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON fileflow.* TO 'fileflow_user'@'%';
  FLUSH PRIVILEGES;
  ```

- [ ] **3.5 Security Group 규칙 설정**
  ```hcl
  # database.tf
  resource "aws_security_group_rule" "shared_rds_from_ecs" {
    type                     = "ingress"
    from_port                = 3306
    to_port                  = 3306
    protocol                 = "tcp"
    source_security_group_id = aws_security_group.ecs_tasks.id
    security_group_id        = data.aws_ssm_parameter.shared_rds_sg_id.value
    description              = "Allow MySQL access from FileFlow ECS tasks"
  }
  ```

- [ ] **3.6 IAM 정책 설정**
  - ECS Task Execution Role: ECR pull, CloudWatch Logs write
  - ECS Task Role: S3, SQS, Secrets Manager, SSM Parameter 접근

#### Phase 4: 첫 배포 실행

**목표**: Terraform 초기화 및 첫 번째 배포

- [ ] **4.1 Terraform 초기화**
  ```bash
  cd /Users/sangwon-ryu/fileflow/infrastructure/terraform
  terraform init
  ```

- [ ] **4.2 Terraform Plan 실행**
  ```bash
  terraform plan -var-file=environments/dev/terraform.tfvars -out=plan.out
  ```

  **확인 사항**:
  - 생성될 리소스 수 확인
  - SSM Parameter 데이터 소스가 올바르게 참조되는지 확인
  - KMS 키 ARN이 올바르게 설정되는지 확인

- [ ] **4.3 Terraform Apply 실행**
  ```bash
  terraform apply plan.out
  ```

- [ ] **4.4 배포 결과 확인**
  ```bash
  # ECS Cluster 확인
  aws ecs describe-clusters --clusters fileflow-dev-cluster --region ap-northeast-2

  # ECS Service 확인
  aws ecs describe-services \
    --cluster fileflow-dev-cluster \
    --services fileflow-dev-service \
    --region ap-northeast-2

  # Task 실행 상태 확인
  aws ecs list-tasks \
    --cluster fileflow-dev-cluster \
    --region ap-northeast-2
  ```

#### Phase 5: 검증 테스트

**목표**: 배포된 인프라가 정상 작동하는지 검증

- [ ] **5.1 네트워크 연결 확인**
  ```bash
  # Security Group 규칙 확인
  aws ec2 describe-security-group-rules \
    --filters "Name=group-id,Values=<ecs-task-sg-id>" \
    --region ap-northeast-2
  ```

- [ ] **5.2 Database 연결 확인**
  ```bash
  # ECS Exec을 통한 Database 연결 테스트 (ECS Exec 활성화 필요)
  aws ecs execute-command \
    --cluster fileflow-dev-cluster \
    --task <task-id> \
    --container fileflow-app \
    --interactive \
    --command "/bin/sh"

  # Container 내부에서 실행
  mysql -h prod-shared-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com \
        -u fileflow_user -p fileflow
  ```

- [ ] **5.3 Secrets Manager 접근 확인**
  ```bash
  # ECS Task Role로 Secrets Manager 접근 테스트
  aws secretsmanager get-secret-value \
    --secret-id fileflow-dev-db-credentials \
    --region ap-northeast-2
  ```

- [ ] **5.4 S3, SQS 접근 확인**
  ```bash
  # S3 버킷 목록 확인
  aws s3 ls s3://fileflow-dev-storage-bucket/

  # SQS 큐 확인
  aws sqs get-queue-attributes \
    --queue-url <queue-url> \
    --attribute-names All \
    --region ap-northeast-2
  ```

- [ ] **5.5 CloudWatch Logs 확인**
  ```bash
  # Log Stream 확인
  aws logs describe-log-streams \
    --log-group-name /ecs/fileflow-dev \
    --region ap-northeast-2

  # 최근 로그 확인
  aws logs tail /ecs/fileflow-dev --follow
  ```

- [ ] **5.6 Health Check 확인**
  ```bash
  # ALB Health Check 확인
  aws elbv2 describe-target-health \
    --target-group-arn <target-group-arn> \
    --region ap-northeast-2

  # HTTP Health Check
  curl http://<alb-dns-name>/actuator/health
  ```

#### Phase 6: 문서화 및 마무리

**목표**: 설정 내용을 문서화하고 팀과 공유

- [ ] **6.1 README.md 작성**
  - 프로젝트 개요
  - 배포 방법
  - 환경 변수 목록
  - 트러블슈팅 가이드

- [ ] **6.2 아키텍처 다이어그램 작성**
  - 네트워크 구성도
  - 데이터 흐름도
  - 보안 그룹 규칙

- [ ] **6.3 팀 공유**
  - Confluence 또는 내부 Wiki에 문서 업로드
  - Slack #infrastructure 채널에 공유
  - Jira 태스크 업데이트

---

## 기술 스택 및 버전 요구사항

### 필수 도구 및 버전

#### Terraform

**최소 버전**: `>= 1.5.0`
**권장 버전**: `>= 1.9.0`
**현재 사용 버전**: `1.12.2`

```bash
# 버전 확인
terraform version

# 설치 (macOS)
brew install terraform

# 설치 (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

#### AWS Provider

**최소 버전**: `>= 5.0`
**권장 버전**: `>= 5.50.0`

```hcl
# provider.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0"
    }
  }
}
```

#### AWS CLI

**최소 버전**: `>= 2.0`
**권장 버전**: `>= 2.15.0`

```bash
# 버전 확인
aws --version

# 설치 (macOS)
brew install awscli

# 설치 (Ubuntu/Debian)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### MySQL Client

**최소 버전**: `>= 8.0`

Database 생성 스크립트 및 수동 관리 작업에 필요합니다.

```bash
# 설치 (macOS)
brew install mysql-client
echo 'export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 설치 (Ubuntu/Debian)
sudo apt-get install mysql-client

# 설치 (Amazon Linux)
sudo yum install mysql

# 버전 확인
mysql --version
```

#### jq

**최소 버전**: `>= 1.6`

JSON 처리 및 스크립트 자동화에 필요합니다.

```bash
# 설치 (macOS)
brew install jq

# 설치 (Ubuntu/Debian)
sudo apt-get install jq

# 설치 (Amazon Linux)
sudo yum install jq

# 버전 확인
jq --version
```

#### Git

**최소 버전**: `>= 2.30`

```bash
# 버전 확인
git --version

# 설치 (macOS)
brew install git

# 설치 (Ubuntu/Debian)
sudo apt-get install git
```

### 운영체제 호환성

#### 지원 운영체제

| OS | 버전 | 상태 | 비고 |
|----|------|------|------|
| **macOS** | >= 12.0 (Monterey) | ✅ 완전 지원 | Apple Silicon (M1/M2/M3) 포함 |
| **Ubuntu** | >= 20.04 LTS | ✅ 완전 지원 | CI/CD 환경 권장 |
| **Debian** | >= 11 | ✅ 완전 지원 | |
| **Amazon Linux** | >= 2023 | ✅ 완전 지원 | EC2 인스턴스에서 작업 시 |
| **Windows** | >= 10 | ⚠️ WSL2 권장 | WSL2 + Ubuntu 사용 |

#### WSL2 설정 (Windows 사용자)

```powershell
# WSL2 설치
wsl --install -d Ubuntu-22.04

# Ubuntu 내부에서 도구 설치
sudo apt update
sudo apt install -y terraform awscli mysql-client jq git
```

### AWS 권한 및 IAM 정책

#### Infrastructure 프로젝트 배포 권한

최소 권한 IAM 정책:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*Vpc*",
        "ec2:*Subnet*",
        "ec2:*InternetGateway*",
        "ec2:*NatGateway*",
        "ec2:*RouteTable*",
        "ec2:*VpcEndpoint*",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:DescribeAddresses",
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:DescribeKey",
        "kms:EnableKeyRotation",
        "kms:GetKeyPolicy",
        "kms:PutKeyPolicy",
        "kms:ListAliases",
        "rds:CreateDBInstance",
        "rds:CreateDBSubnetGroup",
        "rds:CreateDBParameterGroup",
        "rds:DescribeDBInstances",
        "rds:DescribeDBSubnetGroups",
        "rds:ModifyDBInstance",
        "ecr:CreateRepository",
        "ecr:DescribeRepositories",
        "ecr:PutLifecyclePolicy",
        "ecr:SetRepositoryPolicy",
        "ssm:PutParameter",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "ssm:AddTagsToResource"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Application 프로젝트 배포 권한

최소 권한 IAM 정책:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "elasticache:*",
        "s3:CreateBucket",
        "s3:PutBucketPolicy",
        "s3:PutBucketEncryption",
        "s3:PutBucketVersioning",
        "s3:PutLifecycleConfiguration",
        "sqs:CreateQueue",
        "sqs:SetQueueAttributes",
        "sqs:GetQueueAttributes",
        "elasticloadbalancing:*",
        "iam:CreateRole",
        "iam:CreatePolicy",
        "iam:AttachRolePolicy",
        "iam:PassRole",
        "iam:GetRole",
        "iam:GetPolicy",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "secretsmanager:CreateSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:GetSecretValue",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": "*"
    }
  ]
}
```

### 네트워크 요구사항

#### 아웃바운드 접근 필요 도메인

Terraform 및 AWS CLI 작업 시 다음 도메인에 대한 아웃바운드 접근이 필요합니다:

```
# Terraform Registry
registry.terraform.io
releases.hashicorp.com

# AWS 서비스 엔드포인트
*.amazonaws.com
*.aws.amazon.com

# GitHub (모듈 다운로드)
github.com
raw.githubusercontent.com

# Docker Hub / ECR (옵션)
*.docker.io
*.ecr.ap-northeast-2.amazonaws.com
```

#### 방화벽 허용 포트

| 포트 | 프로토콜 | 용도 |
|------|---------|------|
| 443 | HTTPS | Terraform Registry, AWS API |
| 3306 | MySQL | Shared RDS 접근 (개발자 로컬) |
| 6379 | Redis | ElastiCache 접근 (개발자 로컬) |

---

## 사전 요구사항

### 필수 소프트웨어

- **Terraform**: >= 1.5.0
- **AWS CLI**: >= 2.0
- **jq**: JSON 처리 (database 생성 스크립트 용)
- **mysql-client**: Shared RDS database 생성 용
- **Git**: 버전 관리

### AWS 권한

Infrastructure 프로젝트 배포에 필요한 권한:
- VPC, Subnet 생성/관리
- KMS 키 생성/관리
- RDS 인스턴스 생성/관리
- ECR 레포지토리 생성/관리
- SSM Parameter 생성/관리

Application 프로젝트 배포에 필요한 권한:
- ECS Cluster, Service, Task 생성/관리
- ElastiCache 생성/관리
- S3 Bucket 생성/관리
- SQS Queue 생성/관리
- ALB 생성/관리
- IAM Role, Policy 생성/관리
- Security Group 생성/관리
- Secrets Manager Secret 생성/관리
- SSM Parameter 읽기 (SSM Parameters에 접근)

### Infrastructure 프로젝트 사전 배포

**중요**: Application 프로젝트를 배포하기 전에 Infrastructure 프로젝트의 다음 모듈이 **반드시** 배포되어 있어야 합니다:

```bash
# 1. Network 모듈 배포
cd /Users/sangwon-ryu/infrastructure/terraform/network
terraform init
terraform apply

# 2. KMS 모듈 배포
cd /Users/sangwon-ryu/infrastructure/terraform/kms
terraform init
terraform apply

# 3. ECR 모듈 배포 (서비스별)
cd /Users/sangwon-ryu/infrastructure/terraform/ecr
# ECR 레포지토리 생성 (예: fileflow)
terraform init
terraform apply

# 4. Shared RDS 배포 (옵션)
cd /Users/sangwon-ryu/infrastructure/terraform/rds
terraform init
terraform apply
```

### 배포 확인

SSM Parameters가 생성되었는지 확인:

```bash
# 모든 공유 파라미터 조회
aws ssm get-parameters-by-path \
  --path /shared \
  --recursive \
  --region ap-northeast-2

# 특정 파라미터 확인
aws ssm get-parameter \
  --name /shared/network/vpc-id \
  --region ap-northeast-2
```

---

## 다음 단계

이제 개요와 시작 가이드를 완료했습니다. 다음 단계로 넘어가세요:

- **[2️⃣ 아키텍처 설계](hybrid-02-architecture-design.md)**: Infrastructure와 Application 프로젝트의 역할, 데이터 흐름, Producer-Consumer 패턴 이해
- **[3️⃣ Infrastructure 프로젝트 설정](hybrid-03-infrastructure-setup.md)**: 공유 리소스 설정 및 SSM Parameters Export
- **[4️⃣ Application 프로젝트 설정](hybrid-04-application-setup.md)**: 서비스별 인프라 설정 및 data.tf, locals.tf 작성

---

**Last Updated**: 2025-10-22
