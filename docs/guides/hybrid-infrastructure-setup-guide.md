# 하이브리드 Terraform 인프라 구조 설정 가이드

**작성일**: 2025-10-21
**버전**: 1.0
**대상 독자**: DevOps 엔지니어, 플랫폼 팀, 새로운 서비스를 론칭하는 개발팀

---

## 📋 목차

1. [개요](#개요)
2. [빠른 시작 가이드](#빠른-시작-가이드)
3. [기술 스택 및 버전 요구사항](#기술-스택-및-버전-요구사항)
4. [아키텍처 설계](#아키텍처-설계)
5. [사전 요구사항](#사전-요구사항)
6. [Infrastructure 프로젝트 설정](#infrastructure-프로젝트-설정)
7. [Application 프로젝트 설정](#application-프로젝트-설정)
8. [검증 및 배포](#검증-및-배포)
9. [CI/CD 통합](#cicd-통합)
10. [모니터링 및 로깅](#모니터링-및-로깅)
11. [비용 예측 및 최적화](#비용-예측-및-최적화)
12. [운영 가이드](#운영-가이드)
13. [트러블슈팅](#트러블슈팅)
14. [모범 사례](#모범-사례)
15. [FAQ](#faq)

---

## 개요

### 하이브리드 인프라 구조란?

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
  cd /path/to/infrastructure/terraform/network
  terraform init
  terraform plan
  terraform apply
  ```
  - VPC, Subnets, Route Tables 생성 확인
  - SSM Parameters 생성 확인: `/shared/network/*`

- [ ] **1.2 KMS 모듈 배포 확인**
  ```bash
  cd /path/to/infrastructure/terraform/kms
  terraform init
  terraform plan
  terraform apply
  ```
  - 7개 KMS 키 생성 확인 (cloudwatch-logs, secrets-manager, rds, s3, sqs, ssm, elasticache)
  - SSM Parameters 생성 확인: `/shared/kms/*`

- [ ] **1.3 ECR 레포지토리 생성**
  ```bash
  cd /path/to/infrastructure/terraform/ecr/[service-name]
  # 예: cd /path/to/infrastructure/terraform/ecr/fileflow
  terraform init
  terraform plan
  terraform apply
  ```
  - ECR 레포지토리 생성 확인
  - Lifecycle Policy 설정 확인
  - SSM Parameter 생성 확인: `/shared/ecr/[service-name]-repository-url`

- [ ] **1.4 Shared RDS 배포 (옵션, 필요시)**
  ```bash
  cd /path/to/infrastructure/terraform/rds
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
  mkdir -p /path/to/fileflow/infrastructure/terraform
  cd /path/to/fileflow/infrastructure/terraform

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
  cd /path/to/fileflow/infrastructure/terraform
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

## 아키텍처 설계

### Infrastructure 프로젝트 역할 (중앙 관리)

**위치**: `/path/to/infrastructure/terraform/`

#### 관리 대상 리소스

**1. Network (네트워크)**
- VPC 및 CIDR 블록 (`10.0.0.0/16`)
- Public Subnets (Multi-AZ, `/20`)
- Private Subnets (Multi-AZ, `/19`)
- Data Subnets (Multi-AZ, `/20`)
- Internet Gateway
- NAT Gateway
- Route Tables
- VPC Endpoints (S3, DynamoDB, ECR, Secrets Manager)

**2. KMS (암호화 키)**
- CloudWatch Logs 전용 KMS 키
- Secrets Manager 전용 KMS 키
- RDS 전용 KMS 키
- S3 전용 KMS 키
- SQS 전용 KMS 키
- SSM Parameter Store 전용 KMS 키
- ElastiCache 전용 KMS 키

**3. Shared RDS (공유 데이터베이스)**
- Multi-AZ MySQL 인스턴스
- Master credentials (Secrets Manager)
- DB Subnet Group
- Security Group
- Parameter Group
- Automated Backups
- Performance Insights

**4. ECR (컨테이너 레지스트리)**
- 서비스별 ECR 레포지토리
- Lifecycle 정책
- Image 스캔 설정

**5. SSM Parameters (공유 정보 Export)**

모든 공유 리소스는 SSM Parameter Store를 통해 Export됩니다:

```
/shared/network/vpc-id
/shared/network/public-subnet-ids
/shared/network/private-subnet-ids
/shared/network/data-subnet-ids
/shared/kms/cloudwatch-logs-key-arn
/shared/kms/secrets-manager-key-arn
/shared/kms/rds-key-arn
/shared/kms/s3-key-arn
/shared/kms/sqs-key-arn
/shared/kms/ssm-key-arn
/shared/kms/elasticache-key-arn
/shared/ecr/{service-name}-repository-url
```

### Application 프로젝트 역할 (분산 관리)

**위치**: `/path/to/{service-name}/infrastructure/terraform/`

#### 관리 대상 리소스

**1. ECS (컨테이너 오케스트레이션)**
- ECS Cluster
- ECS Service
- Task Definition
- Container Definition
- Auto Scaling Policy
- Security Groups

**2. Shared RDS 연결**
- Security Group Rule (ECS → RDS)
- Service-specific Database 생성
- Service-specific User 생성
- Database Credentials (Secrets Manager)

**3. ElastiCache Redis**
- Redis Replication Group
- Subnet Group
- Parameter Group
- Security Group

**4. S3 Buckets**
- Storage Bucket
- Logs Bucket
- Bucket Policies
- Lifecycle Rules

**5. SQS Queues**
- Standard/FIFO Queues
- Dead Letter Queues
- Queue Policies

**6. Application Load Balancer**
- ALB
- Target Groups
- Listener Rules
- Security Groups

**7. IAM Roles and Policies**
- ECS Task Execution Role
- ECS Task Role
- Service-specific Policies

### 데이터 흐름 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│ Infrastructure Repository (중앙 관리)                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────┐   ┌────────────┐   ┌─────────────┐        │
│  │ VPC        │   │ KMS Keys   │   │ Shared RDS  │        │
│  │ 10.0.0.0/16│   │ 7 keys     │   │ prod-shared │        │
│  └─────┬──────┘   └─────┬──────┘   └──────┬──────┘        │
│        │                │                  │                │
│        └────────────────┴──────────────────┘                │
│                         │                                   │
│                   SSM Parameters                            │
│         /shared/network/*, /shared/kms/*                    │
│                         │                                   │
└─────────────────────────┼───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Application Repository (FileFlow)                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────┐                  │
│  │ data.tf (SSM Parameter 데이터 소스)   │                  │
│  ├──────────────────────────────────────┤                  │
│  │ data "aws_ssm_parameter" "vpc_id"    │                  │
│  │ data "aws_ssm_parameter" "kms_arns"  │                  │
│  └────────────┬─────────────────────────┘                  │
│               │                                             │
│               ▼                                             │
│  ┌──────────────────────────────────────┐                  │
│  │ locals.tf (값 참조)                   │                  │
│  ├──────────────────────────────────────┤                  │
│  │ vpc_id = data.aws_ssm_parameter...   │                  │
│  │ cloudwatch_key_arn = data.aws...    │                  │
│  └────────────┬─────────────────────────┘                  │
│               │                                             │
│               ▼                                             │
│  ┌────────────────────────────────────────────────┐        │
│  │ Application Resources                          │        │
│  ├────────────────────────────────────────────────┤        │
│  │ • ECS (local.vpc_id, local.private_subnet_ids)│        │
│  │ • Redis (local.elasticache_key_arn)           │        │
│  │ • S3 (local.s3_key_arn)                       │        │
│  │ • SQS (local.sqs_key_arn)                     │        │
│  │ • Database (Shared RDS connection)            │        │
│  └────────────────────────────────────────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Shared RDS 내부 구조:
┌─────────────────────────────────────┐
│ prod-shared-mysql                   │
├─────────────────────────────────────┤
│ Database: fileflow                  │
│ User: fileflow_user                 │
│ Privileges: CRUD, DDL               │
├─────────────────────────────────────┤
│ Database: authhub                   │
│ User: authhub_user                  │
│ Privileges: CRUD, DDL               │
├─────────────────────────────────────┤
│ Database: crawler                   │
│ User: crawler_user                  │
│ Privileges: CRUD, DDL               │
└─────────────────────────────────────┘
```

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
cd /path/to/infrastructure/terraform/network
terraform init
terraform apply

# 2. KMS 모듈 배포
cd /path/to/infrastructure/terraform/kms
terraform init
terraform apply

# 3. ECR 모듈 배포 (서비스별)
cd /path/to/infrastructure/terraform/ecr
# ECR 레포지토리 생성 (예: fileflow)
terraform init
terraform apply

# 4. Shared RDS 배포 (옵션)
cd /path/to/infrastructure/terraform/rds
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

## Infrastructure 프로젝트 설정

### 디렉토리 구조

```
infrastructure/terraform/
├── network/              # VPC, Subnets, Route Tables
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf       # SSM Parameter exports
│   └── locals.tf
├── kms/                  # KMS Keys (7개)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf       # SSM Parameter exports
│   └── locals.tf
├── rds/                  # Shared RDS Instance
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── locals.tf
└── ecr/                  # ECR Repositories
    ├── fileflow/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf   # SSM Parameter exports
    ├── authhub/
    └── crawler/
```

### SSM Parameters 생성 방법

#### Network SSM Parameters

**파일**: `infrastructure/terraform/network/outputs.tf`

```hcl
# VPC ID
resource "aws_ssm_parameter" "vpc_id" {
  name        = "/shared/network/vpc-id"
  description = "VPC ID for cross-stack references"
  type        = "String"
  value       = aws_vpc.main.id

  tags = merge(
    local.required_tags,
    {
      Name      = "vpc-id-export"
      Component = "network"
    }
  )
}

# Public Subnet IDs
resource "aws_ssm_parameter" "public_subnet_ids" {
  name        = "/shared/network/public-subnet-ids"
  description = "Public subnet IDs for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_subnet.public[*].id)

  tags = merge(
    local.required_tags,
    {
      Name      = "public-subnet-ids-export"
      Component = "network"
    }
  )
}

# Private Subnet IDs
resource "aws_ssm_parameter" "private_subnet_ids" {
  name        = "/shared/network/private-subnet-ids"
  description = "Private subnet IDs for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_subnet.private[*].id)

  tags = merge(
    local.required_tags,
    {
      Name      = "private-subnet-ids-export"
      Component = "network"
    }
  )
}

# Data Subnet IDs (RDS, ElastiCache 용)
resource "aws_ssm_parameter" "data_subnet_ids" {
  name        = "/shared/network/data-subnet-ids"
  description = "Data subnet IDs for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_subnet.data[*].id)

  tags = merge(
    local.required_tags,
    {
      Name      = "data-subnet-ids-export"
      Component = "network"
    }
  )
}
```

#### KMS SSM Parameters

**파일**: `infrastructure/terraform/kms/outputs.tf`

```hcl
# CloudWatch Logs KMS Key
resource "aws_ssm_parameter" "cloudwatch_logs_key_arn" {
  name        = "/shared/kms/cloudwatch-logs-key-arn"
  description = "CloudWatch Logs KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.cloudwatch-logs.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "cloudwatch-logs-key-arn-export"
      Component = "kms"
    }
  )
}

# Secrets Manager KMS Key
resource "aws_ssm_parameter" "secrets_manager_key_arn" {
  name        = "/shared/kms/secrets-manager-key-arn"
  description = "Secrets Manager KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.secrets-manager.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "secrets-manager-key-arn-export"
      Component = "kms"
    }
  )
}

# RDS KMS Key
resource "aws_ssm_parameter" "rds_key_arn" {
  name        = "/shared/kms/rds-key-arn"
  description = "RDS KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.rds.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "rds-key-arn-export"
      Component = "kms"
    }
  )
}

# S3 KMS Key
resource "aws_ssm_parameter" "s3_key_arn" {
  name        = "/shared/kms/s3-key-arn"
  description = "S3 KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.s3.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "s3-key-arn-export"
      Component = "kms"
    }
  )
}

# SQS KMS Key
resource "aws_ssm_parameter" "sqs_key_arn" {
  name        = "/shared/kms/sqs-key-arn"
  description = "SQS KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.sqs.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "sqs-key-arn-export"
      Component = "kms"
    }
  )
}

# SSM Parameter Store KMS Key
resource "aws_ssm_parameter" "ssm_key_arn" {
  name        = "/shared/kms/ssm-key-arn"
  description = "SSM Parameter Store KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.ssm.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "ssm-key-arn-export"
      Component = "kms"
    }
  )
}

# ElastiCache KMS Key
resource "aws_ssm_parameter" "elasticache_key_arn" {
  name        = "/shared/kms/elasticache-key-arn"
  description = "ElastiCache KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.elasticache.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "elasticache-key-arn-export"
      Component = "kms"
    }
  )
}
```

#### ECR SSM Parameters

**파일**: `infrastructure/terraform/ecr/fileflow/outputs.tf`

```hcl
# ECR Repository URL
resource "aws_ssm_parameter" "ecr_repository_url" {
  name        = "/shared/ecr/fileflow-repository-url"
  description = "FileFlow ECR repository URL for cross-stack references"
  type        = "String"
  value       = aws_ecr_repository.fileflow.repository_url

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-ecr-url-export"
      Component = "ecr"
    }
  )
}

# ECR Repository ARN
resource "aws_ssm_parameter" "ecr_repository_arn" {
  name        = "/shared/ecr/fileflow-repository-arn"
  description = "FileFlow ECR repository ARN for cross-stack references"
  type        = "String"
  value       = aws_ecr_repository.fileflow.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-ecr-arn-export"
      Component = "ecr"
    }
  )
}
```

### Shared RDS 설정

#### Shared RDS 인스턴스 생성

**파일**: `infrastructure/terraform/rds/main.tf`

```hcl
# Random password for RDS master user
resource "random_password" "master" {
  length  = 32
  special = true
}

# Store master credentials in Secrets Manager
resource "aws_secretsmanager_secret" "rds_master" {
  name_prefix             = "${var.environment}-shared-mysql-master-"
  description             = "Master credentials for shared MySQL RDS instance"
  kms_key_id              = data.aws_ssm_parameter.secrets_manager_key_arn.value
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-master"
      Component = "rds"
    }
  )
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = aws_secretsmanager_secret.rds_master.id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.master.result
    engine   = "mysql"
    host     = aws_db_instance.shared.endpoint
    port     = 3306
  })
}

# DB Subnet Group
resource "aws_db_subnet_group" "shared" {
  name       = "${var.environment}-shared-mysql-subnet-group"
  subnet_ids = split(",", data.aws_ssm_parameter.data_subnet_ids.value)

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-subnet-group"
      Component = "rds"
    }
  )
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.environment}-shared-mysql-"
  description = "Security group for shared MySQL RDS instance"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  # Allow MySQL from private subnets
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "Allow MySQL from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-sg"
      Component = "rds"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Instance
resource "aws_db_instance" "shared" {
  identifier = "${var.environment}-shared-mysql"

  # Engine
  engine               = "mysql"
  engine_version       = "8.0.42"
  instance_class       = var.environment == "prod" ? "db.t3.medium" : "db.t3.small"
  allocated_storage    = var.environment == "prod" ? 100 : 20
  max_allocated_storage = var.environment == "prod" ? 500 : 100
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id          = data.aws_ssm_parameter.rds_key_arn.value

  # Credentials
  username = "admin"
  password = random_password.master.result

  # Network
  db_subnet_group_name   = aws_db_subnet_group.shared.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High Availability
  multi_az = var.environment == "prod"

  # Backup
  backup_retention_period = var.environment == "prod" ? 7 : 3
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  skip_final_snapshot    = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.environment}-shared-mysql-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Performance Insights
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  performance_insights_enabled    = true
  performance_insights_kms_key_id = data.aws_ssm_parameter.cloudwatch_logs_key_arn.value

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.shared.name

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql"
      Component = "rds"
    }
  )
}

# DB Parameter Group
resource "aws_db_parameter_group" "shared" {
  name_prefix = "${var.environment}-shared-mysql-"
  family      = "mysql8.0"
  description = "Parameter group for shared MySQL RDS instance"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = var.environment == "prod" ? "200" : "100"
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-params"
      Component = "rds"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
```

#### Shared RDS Outputs

**파일**: `infrastructure/terraform/rds/outputs.tf`

```hcl
output "db_instance_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.shared.identifier
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.shared.endpoint
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.shared.arn
}

output "db_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "master_secret_arn" {
  description = "ARN of master credentials secret"
  value       = aws_secretsmanager_secret.rds_master.arn
}

# SSM Parameter Export for Application projects
resource "aws_ssm_parameter" "shared_rds_identifier" {
  name        = "/shared/rds/${var.environment}/identifier"
  description = "Shared RDS instance identifier"
  type        = "String"
  value       = aws_db_instance.shared.identifier

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-identifier-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "shared_rds_endpoint" {
  name        = "/shared/rds/${var.environment}/endpoint"
  description = "Shared RDS instance endpoint"
  type        = "String"
  value       = aws_db_instance.shared.endpoint

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-endpoint-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "shared_rds_security_group_id" {
  name        = "/shared/rds/${var.environment}/security-group-id"
  description = "Shared RDS security group ID"
  type        = "String"
  value       = aws_security_group.rds.id

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-sg-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "shared_rds_master_secret_arn" {
  name        = "/shared/rds/${var.environment}/master-secret-arn"
  description = "Shared RDS master credentials secret ARN"
  type        = "String"
  value       = aws_secretsmanager_secret.rds_master.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-master-secret-export"
      Component = "rds"
    }
  )
}
```

---

## Application 프로젝트 설정

### Step 1: 프로젝트 구조 생성

```bash
cd /path/to/{service-name}

# 디렉토리 생성
mkdir -p infrastructure/terraform/{environments/{dev,staging,prod},modules}
mkdir -p infrastructure/scripts
mkdir -p .github/workflows
```

**결과 구조**:

```
{service-name}/
├── infrastructure/
│   ├── terraform/
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   │   └── terraform.tfvars
│   │   │   ├── staging/
│   │   │   │   └── terraform.tfvars
│   │   │   └── prod/
│   │   │       └── terraform.tfvars
│   │   ├── modules/          # (Infrastructure repo에서 복사)
│   │   ├── data.tf           # SSM Parameter 데이터 소스
│   │   ├── locals.tf         # SSM Parameter 값 참조
│   │   ├── variables.tf      # 서비스별 변수
│   │   ├── provider.tf       # Terraform 및 AWS Provider
│   │   ├── database.tf       # Shared RDS 연결
│   │   ├── ecs.tf            # ECS 클러스터 및 서비스
│   │   ├── redis.tf          # ElastiCache Redis
│   │   ├── s3.tf             # S3 버킷
│   │   ├── sqs.tf            # SQS 큐
│   │   ├── alb.tf            # Application Load Balancer
│   │   ├── iam.tf            # IAM 역할 및 정책
│   │   └── outputs.tf        # 출력 값
│   └── scripts/
│       └── deploy.sh
├── .github/
│   └── workflows/
│       ├── build-and-push.yml
│       └── deploy.yml
└── db/
    └── migration/
        ├── V001__initial_schema.sql
        └── ...
```

### Step 2: data.tf 작성 (SSM Parameter 데이터 소스)

**파일**: `infrastructure/terraform/data.tf`

FileFlow 프로젝트의 실제 예제:

```hcl
# ============================================================================
# Data Sources for Shared Infrastructure
# ============================================================================

# Account information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# Network Information (from SSM Parameters)
# ============================================================================

data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/shared/network/private-subnet-ids"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "/shared/network/public-subnet-ids"
}

data "aws_ssm_parameter" "data_subnet_ids" {
  name = "/shared/network/data-subnet-ids"
}

# VPC 정보 직접 조회 (fallback)
data "aws_vpc" "main" {
  id = local.vpc_id
}

# Subnets 직접 조회 (fallback)
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  tags = {
    Tier = "private"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  tags = {
    Tier = "public"
  }
}

# ============================================================================
# KMS Keys (from SSM Parameters)
# ============================================================================

data "aws_ssm_parameter" "cloudwatch_logs_key_arn" {
  name = "/shared/kms/cloudwatch-logs-key-arn"
}

data "aws_ssm_parameter" "secrets_manager_key_arn" {
  name = "/shared/kms/secrets-manager-key-arn"
}

data "aws_ssm_parameter" "rds_key_arn" {
  name = "/shared/kms/rds-key-arn"
}

data "aws_ssm_parameter" "s3_key_arn" {
  name = "/shared/kms/s3-key-arn"
}

data "aws_ssm_parameter" "sqs_key_arn" {
  name = "/shared/kms/sqs-key-arn"
}

data "aws_ssm_parameter" "ssm_key_arn" {
  name = "/shared/kms/ssm-key-arn"
}

data "aws_ssm_parameter" "elasticache_key_arn" {
  name = "/shared/kms/elasticache-key-arn"
}

# ============================================================================
# ECR Repository (from SSM Parameters)
# ============================================================================

data "aws_ssm_parameter" "ecr_repository_url" {
  name = "/shared/ecr/fileflow-repository-url"
}

# ============================================================================
# Shared RDS Information (from SSM Parameters - Optional)
# ============================================================================

# Shared RDS를 사용하는 경우 추가
data "aws_ssm_parameter" "shared_rds_identifier" {
  name = "/shared/rds/${var.environment}/identifier"
}

data "aws_ssm_parameter" "shared_rds_security_group_id" {
  name = "/shared/rds/${var.environment}/security-group-id"
}

data "aws_ssm_parameter" "shared_rds_master_secret_arn" {
  name = "/shared/rds/${var.environment}/master-secret-arn"
}
```

### Step 3: locals.tf 작성 (SSM Parameter 값 참조)

**파일**: `infrastructure/terraform/locals.tf`

```hcl
# ============================================================================
# Local Variables
# ============================================================================

locals {
  # Account and Region
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Naming
  name_prefix  = "${var.service_name}-${var.environment}"
  service_name = var.service_name

  # Network (from SSM Parameters)
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  public_subnet_ids  = split(",", data.aws_ssm_parameter.public_subnet_ids.value)
  data_subnet_ids    = split(",", data.aws_ssm_parameter.data_subnet_ids.value)

  # KMS Keys (from SSM Parameters)
  cloudwatch_key_arn  = data.aws_ssm_parameter.cloudwatch_logs_key_arn.value
  secrets_key_arn     = data.aws_ssm_parameter.secrets_manager_key_arn.value
  rds_key_arn         = data.aws_ssm_parameter.rds_key_arn.value
  s3_key_arn          = data.aws_ssm_parameter.s3_key_arn.value
  sqs_key_arn         = data.aws_ssm_parameter.sqs_key_arn.value
  ssm_key_arn         = data.aws_ssm_parameter.ssm_key_arn.value
  elasticache_key_arn = data.aws_ssm_parameter.elasticache_key_arn.value

  # ECR (from SSM Parameters)
  ecr_repository_url = data.aws_ssm_parameter.ecr_repository_url.value

  # Shared RDS (from SSM Parameters - Optional)
  shared_rds_identifier        = try(data.aws_ssm_parameter.shared_rds_identifier.value, "")
  shared_rds_security_group_id = try(data.aws_ssm_parameter.shared_rds_security_group_id.value, "")
  shared_rds_master_secret_arn = try(data.aws_ssm_parameter.shared_rds_master_secret_arn.value, "")

  # Required Tags
  required_tags = {
    Environment = var.environment
    Service     = var.service_name
    Owner       = var.tags_owner
    CostCenter  = var.tags_cost_center
    Team        = var.tags_team
    Lifecycle   = var.environment == "prod" ? "critical" : "non-critical"
    DataClass   = "sensitive"
    ManagedBy   = "Terraform"
    Repository  = var.service_name
  }
}
```

### Step 4: variables.tf 작성

**파일**: `infrastructure/terraform/variables.tf`

```hcl
# ============================================================================
# Core Variables
# ============================================================================

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "service_name" {
  description = "Service name"
  type        = string
  default     = "fileflow"
}

# ============================================================================
# Shared RDS Configuration (Shared RDS 사용 시)
# ============================================================================

variable "shared_rds_identifier" {
  description = "Identifier of the shared RDS instance"
  type        = string
  default     = ""
}

variable "shared_rds_master_secret_arn" {
  description = "ARN of Secrets Manager secret for shared RDS master credentials"
  type        = string
  default     = ""
}

variable "shared_rds_security_group_id" {
  description = "Security group ID of shared RDS"
  type        = string
  default     = ""
}

# ============================================================================
# Database Configuration
# ============================================================================

variable "db_name" {
  description = "Database name for this service"
  type        = string
  default     = "fileflow"
}

variable "db_username" {
  description = "Database username for this service"
  type        = string
  default     = "fileflow_user"
}

# ============================================================================
# ECS Configuration
# ============================================================================

variable "ecs_task_cpu" {
  description = "ECS task CPU units"
  type        = string
  default     = "512"
}

variable "ecs_task_memory" {
  description = "ECS task memory (MB)"
  type        = string
  default     = "1024"
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

# ============================================================================
# Redis Configuration
# ============================================================================

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

# ============================================================================
# Tags
# ============================================================================

variable "tags_owner" {
  description = "Owner tag value"
  type        = string
  default     = "platform-team"
}

variable "tags_cost_center" {
  description = "Cost center tag value"
  type        = string
  default     = "engineering"
}

variable "tags_team" {
  description = "Team tag value"
  type        = string
  default     = "platform-team"
}
```

### Step 5: database.tf 작성 (Shared RDS 연결)

**파일**: `infrastructure/terraform/database.tf`

FileFlow 프로젝트의 실제 예제 (완전한 코드):

```hcl
# ============================================================================
# Database Configuration (Shared RDS)
# ============================================================================

# Data source to get shared RDS instance
data "aws_db_instance" "shared" {
  db_instance_identifier = var.shared_rds_identifier
}

# Security group rule to allow ECS tasks to access shared RDS
resource "aws_security_group_rule" "shared_rds_from_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = var.shared_rds_security_group_id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "Allow MySQL access from FileFlow ECS tasks"
}

# Random password for service-specific database user
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Store service-specific database credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix             = "${local.name_prefix}-db-credentials-"
  description             = "Database credentials for ${var.service_name} service"
  kms_key_id              = local.secrets_key_arn
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-db-credentials"
      Component = "database"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    database = var.db_name
    host     = data.aws_db_instance.shared.endpoint
    port     = 3306
  })
}

# MySQL database and user creation using null_resource
resource "null_resource" "create_database_and_user" {
  # Trigger on database name or username changes
  triggers = {
    db_name      = var.db_name
    db_username  = var.db_username
    rds_endpoint = data.aws_db_instance.shared.endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for RDS to be available
      sleep 30

      # Get master credentials from Secrets Manager
      MASTER_CREDS=$(aws secretsmanager get-secret-value \
        --secret-id ${var.shared_rds_master_secret_arn} \
        --query SecretString \
        --output text \
        --region ${var.aws_region})

      MASTER_USER=$(echo $MASTER_CREDS | jq -r .username)
      MASTER_PASS=$(echo $MASTER_CREDS | jq -r .password)
      RDS_HOST="${data.aws_db_instance.shared.endpoint}"

      # Create database and user
      mysql -h "$RDS_HOST" -u "$MASTER_USER" -p"$MASTER_PASS" << 'SQL'
        -- Create database if not exists
        CREATE DATABASE IF NOT EXISTS ${var.db_name}
          CHARACTER SET utf8mb4
          COLLATE utf8mb4_unicode_ci;

        -- Create user if not exists
        CREATE USER IF NOT EXISTS '${var.db_username}'@'%'
          IDENTIFIED BY '${random_password.db_password.result}';

        -- Grant minimal required privileges
        GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
          ON ${var.db_name}.* TO '${var.db_username}'@'%';

        -- Flush privileges
        FLUSH PRIVILEGES;
      SQL

      echo "Database ${var.db_name} and user ${var.db_username} created successfully"
    EOT
  }

  depends_on = [
    random_password.db_password,
    aws_secretsmanager_secret_version.db_credentials
  ]
}

# IAM policy for accessing service-specific database credentials
resource "aws_iam_policy" "db_access" {
  name        = "${local.name_prefix}-db-access"
  description = "Policy for ${var.service_name} to access its database credentials"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn,
          "${aws_secretsmanager_secret.db_credentials.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = local.secrets_key_arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-db-access"
      Component = "iam"
    }
  )
}

# Attach database access policy to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_task_db" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.db_access.arn
}

# CloudWatch Log Group for database query logs (optional)
resource "aws_cloudwatch_log_group" "database_queries" {
  name              = "/aws/rds/${local.service_name}/queries"
  retention_in_days = 7
  kms_key_id        = local.cloudwatch_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-db-queries"
      Component = "logging"
    }
  )
}
```

### Step 6: 리소스별 KMS Key 매핑

**중요**: 각 리소스는 **전용 KMS key**를 사용해야 합니다.

| 리소스 타입 | KMS Key 로컬 변수 | 사용 예제 |
|------------|-------------------|----------|
| CloudWatch Logs | `local.cloudwatch_key_arn` | Log Groups |
| Secrets Manager | `local.secrets_key_arn` | DB Credentials, API Keys |
| RDS | `local.rds_key_arn` | RDS Storage Encryption |
| S3 | `local.s3_key_arn` | S3 Bucket Encryption |
| SQS | `local.sqs_key_arn` | SQS Queue Encryption |
| SSM Parameters | `local.ssm_key_arn` | Secure String Parameters |
| ElastiCache | `local.elasticache_key_arn` | Redis at-rest encryption |

#### Redis 예제

**파일**: `infrastructure/terraform/redis.tf`

```hcl
module "redis" {
  source = "../modules/elasticache"

  name               = "${local.name_prefix}-redis"
  engine_version     = "7.0"
  node_type          = var.redis_node_type
  num_cache_nodes    = var.redis_num_cache_nodes
  parameter_group_family = "redis7"

  # Network
  subnet_ids         = local.data_subnet_ids
  security_group_ids = [aws_security_group.redis.id]

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token_enabled         = true
  kms_key_id                 = local.elasticache_key_arn  # ✅ ElastiCache 전용 키

  # Tags
  common_tags = local.required_tags
}
```

#### SQS 예제

**파일**: `infrastructure/terraform/sqs.tf`

```hcl
module "file_processing_queue" {
  source = "../modules/sqs"

  name                      = "${local.name_prefix}-file-processing"
  message_retention_seconds = 1209600  # 14 days
  visibility_timeout_seconds = 300

  # Encryption
  kms_master_key_id = local.sqs_key_arn  # ✅ SQS 전용 키

  # Dead Letter Queue
  enable_dlq               = true
  max_receive_count        = 3
  dlq_message_retention_seconds = 1209600

  # Tags
  common_tags = local.required_tags
}
```

#### S3 예제

**파일**: `infrastructure/terraform/s3.tf`

```hcl
module "storage_bucket" {
  source = "../modules/s3-bucket"

  bucket_name = "${local.name_prefix}-storage"

  # Encryption
  enable_encryption     = true
  kms_master_key_id    = local.s3_key_arn  # ✅ S3 전용 키

  # Versioning
  enable_versioning = var.environment == "prod"

  # Lifecycle
  lifecycle_rules = [
    {
      id      = "archive-old-files"
      enabled = true

      transition = [
        {
          days          = 90
          storage_class = "STANDARD_IA"
        },
        {
          days          = 365
          storage_class = "GLACIER"
        }
      ]

      expiration = {
        days = 2555  # 7 years
      }
    }
  ]

  # Tags
  common_tags = local.required_tags
}
```

### Step 7: iam.tf 작성 (로컬 변수 참조)

**중요**: Remote state 대신 로컬 변수 사용

**파일**: `infrastructure/terraform/iam.tf`

```hcl
# ============================================================================
# ECS Task Execution Role
# ============================================================================

resource "aws_iam_role" "ecs_execution_role" {
  name_prefix = "${local.name_prefix}-ecs-execution-"
  description = "ECS task execution role for ${var.service_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-execution-role"
      Component = "iam"
    }
  )
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for ECR and Secrets Manager access
resource "aws_iam_policy" "ecs_execution_custom" {
  name_prefix = "${local.name_prefix}-ecs-execution-custom-"
  description = "Custom policy for ECS task execution"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.app.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        # ❌ 잘못된 방법 (remote state 사용)
        # Resource = data.terraform_remote_state.kms.outputs.secrets_manager_key_arn

        # ✅ 올바른 방법 (로컬 변수 사용)
        Resource = local.secrets_key_arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-execution-custom"
      Component = "iam"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_execution_custom" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_custom.arn
}

# ============================================================================
# ECS Task Role
# ============================================================================

resource "aws_iam_role" "ecs_task_role" {
  name_prefix = "${local.name_prefix}-ecs-task-"
  description = "ECS task role for ${var.service_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-task-role"
      Component = "iam"
    }
  )
}

# S3 access policy
resource "aws_iam_policy" "s3_access" {
  name_prefix = "${local.name_prefix}-s3-access-"
  description = "Policy for ${var.service_name} to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.storage_bucket.bucket_arn,
          "${module.storage_bucket.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        # ✅ 로컬 변수 사용
        Resource = local.s3_key_arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-s3-access"
      Component = "iam"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# SQS access policy
resource "aws_iam_policy" "sqs_access" {
  name_prefix = "${local.name_prefix}-sqs-access-"
  description = "Policy for ${var.service_name} to access SQS queues"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          module.file_processing_queue.queue_arn,
          module.file_upload_queue.queue_arn,
          module.file_completion_queue.queue_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        # ✅ 로컬 변수 사용
        Resource = local.sqs_key_arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-sqs-access"
      Component = "iam"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_sqs" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.sqs_access.arn
}
```

### Step 8: 환경별 terraform.tfvars 작성

#### Production 환경

**파일**: `infrastructure/terraform/environments/prod/terraform.tfvars`

```hcl
# Environment
environment = "prod"
aws_region  = "ap-northeast-2"

# Service
service_name = "fileflow"

# Shared RDS Configuration
shared_rds_identifier        = "prod-shared-mysql"
shared_rds_master_secret_arn = "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:prod-shared-mysql-master-XXXXX"
shared_rds_security_group_id = "sg-xxxxxxxxxxxxx"

# Database
db_name     = "fileflow"
db_username = "fileflow_user"

# ECS Configuration
ecs_task_cpu       = "2048"
ecs_task_memory    = "4096"
ecs_desired_count  = 3
ecs_container_port = 8080

# Redis Configuration
redis_node_type       = "cache.t3.medium"
redis_num_cache_nodes = 2

# Tags
tags_owner       = "platform-team"
tags_cost_center = "engineering"
tags_team        = "platform-team"
```

#### Staging 환경

**파일**: `infrastructure/terraform/environments/staging/terraform.tfvars`

```hcl
# Environment
environment = "staging"
aws_region  = "ap-northeast-2"

# Service
service_name = "fileflow"

# Shared RDS Configuration
shared_rds_identifier        = "staging-shared-mysql"
shared_rds_master_secret_arn = "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:staging-shared-mysql-master-XXXXX"
shared_rds_security_group_id = "sg-xxxxxxxxxxxxx"

# Database
db_name     = "fileflow"
db_username = "fileflow_user"

# ECS Configuration
ecs_task_cpu       = "1024"
ecs_task_memory    = "2048"
ecs_desired_count  = 2
ecs_container_port = 8080

# Redis Configuration
redis_node_type       = "cache.t3.small"
redis_num_cache_nodes = 1

# Tags
tags_owner       = "platform-team"
tags_cost_center = "engineering"
tags_team        = "platform-team"
```

#### Development 환경

**파일**: `infrastructure/terraform/environments/dev/terraform.tfvars`

```hcl
# Environment
environment = "dev"
aws_region  = "ap-northeast-2"

# Service
service_name = "fileflow"

# Shared RDS Configuration
shared_rds_identifier        = "dev-shared-mysql"
shared_rds_master_secret_arn = "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:dev-shared-mysql-master-XXXXX"
shared_rds_security_group_id = "sg-xxxxxxxxxxxxx"

# Database
db_name     = "fileflow"
db_username = "fileflow_user"

# ECS Configuration
ecs_task_cpu       = "512"
ecs_task_memory    = "1024"
ecs_desired_count  = 1
ecs_container_port = 8080

# Redis Configuration
redis_node_type       = "cache.t3.micro"
redis_num_cache_nodes = 1

# Tags
tags_owner       = "platform-team"
tags_cost_center = "engineering"
tags_team        = "platform-team"
```

---

## 검증 및 배포

### Terraform 검증

```bash
cd {service-name}/infrastructure/terraform

# 1. 초기화
terraform init

# 2. 형식 확인
terraform fmt -recursive

# 3. 구문 검증
terraform validate

# 4. Plan 확인 (Dev 환경)
terraform plan -var-file=environments/dev/terraform.tfvars

# 5. Plan 확인 (Staging 환경)
terraform plan -var-file=environments/staging/terraform.tfvars

# 6. Plan 확인 (Prod 환경)
terraform plan -var-file=environments/prod/terraform.tfvars
```

### 배포 전 체크리스트

- [ ] **Infrastructure 프로젝트 배포 완료**
  - [ ] Network 모듈 배포 완료
  - [ ] KMS 모듈 배포 완료
  - [ ] Shared RDS 배포 완료 (사용 시)
  - [ ] ECR Repository 배포 완료

- [ ] **SSM Parameters 확인**
  ```bash
  # 모든 SSM Parameters 확인
  aws ssm get-parameters-by-path --path /shared --recursive

  # 특정 Parameter 확인
  aws ssm get-parameter --name /shared/network/vpc-id
  aws ssm get-parameter --name /shared/kms/s3-key-arn
  ```

- [ ] **Application Terraform 파일 준비**
  - [ ] `data.tf`: 모든 필요한 SSM Parameter 데이터 소스 추가
  - [ ] `locals.tf`: 모든 SSM Parameter 값 참조
  - [ ] `database.tf`: Shared RDS 연결 (사용 시)
  - [ ] 모든 리소스: 올바른 KMS key 사용
  - [ ] `iam.tf`: Remote state 제거, 로컬 변수 사용
  - [ ] 환경별 `terraform.tfvars` 작성 완료

- [ ] **Terraform 검증**
  - [ ] `terraform init` 성공
  - [ ] `terraform validate` 통과
  - [ ] `terraform plan` 검토 완료 (예상 리소스 생성 확인)

- [ ] **보안 검증**
  - [ ] 모든 KMS 암호화 활성화
  - [ ] Secrets Manager 사용 (하드코딩 없음)
  - [ ] Security Group 최소 권한
  - [ ] IAM 역할 최소 권한

### 배포 실행

```bash
# Dev 환경 배포
terraform apply -var-file=environments/dev/terraform.tfvars

# Staging 환경 배포
terraform apply -var-file=environments/staging/terraform.tfvars

# Prod 환경 배포 (수동 확인 필요)
terraform apply -var-file=environments/prod/terraform.tfvars
```

### 배포 후 검증

```bash
# 1. ECS 서비스 상태 확인
aws ecs describe-services \
  --cluster fileflow-dev-cluster \
  --services fileflow-dev-service \
  --region ap-northeast-2

# 2. Task 상태 확인
aws ecs list-tasks \
  --cluster fileflow-dev-cluster \
  --service-name fileflow-dev-service \
  --region ap-northeast-2

# 3. RDS 연결 확인 (ECS Exec)
aws ecs execute-command \
  --cluster fileflow-dev-cluster \
  --task <task-id> \
  --container fileflow \
  --command "/bin/sh" \
  --interactive

# Container 내부에서
mysql -h <rds-endpoint> -u fileflow_user -p

# 4. Redis 연결 확인
redis-cli -h <redis-endpoint> ping

# 5. ALB Health Check 확인
curl http://<alb-dns-name>/actuator/health
```

---

## CI/CD 통합

### GitHub Actions 워크플로

하이브리드 인프라 구조에서는 Infrastructure 프로젝트와 Application 프로젝트 각각에 CI/CD 파이프라인을 구성합니다.

#### Infrastructure 프로젝트 워크플로

**파일**: `/path/to/infrastructure/.github/workflows/terraform-plan.yml`

```yaml
name: Terraform Plan

on:
  pull_request:
    branches:
      - main
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-*.yml'

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: ap-northeast-2

      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: terraform

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/${{ matrix.module }}

      - name: Terraform Validate
        run: terraform validate
        working-directory: terraform/${{ matrix.module }}

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan -no-color -out=plan.out
          terraform show -no-color plan.out > plan.txt
        working-directory: terraform/${{ matrix.module }}
        continue-on-error: true

      - name: Comment PR with Plan
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('terraform/${{ matrix.module }}/plan.txt', 'utf8');

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan - ${{ matrix.module }}\n\`\`\`terraform\n${plan}\n\`\`\``
            });

    strategy:
      matrix:
        module:
          - network
          - kms
          - rds
          - ecr/fileflow
```

**파일**: `/path/to/infrastructure/.github/workflows/terraform-apply.yml`

```yaml
name: Terraform Apply

on:
  push:
    branches:
      - main
    paths:
      - 'terraform/**'
  workflow_dispatch:
    inputs:
      module:
        description: 'Terraform module to apply'
        required: true
        type: choice
        options:
          - network
          - kms
          - rds
          - ecr

permissions:
  contents: read
  id-token: write

jobs:
  terraform-apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    timeout-minutes: 20
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: ap-northeast-2

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/${{ github.event.inputs.module || 'network' }}

      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: terraform/${{ github.event.inputs.module || 'network' }}
```

#### Application 프로젝트 워크플로

**파일**: `/path/to/fileflow/.github/workflows/terraform-plan.yml`

```yaml
name: Terraform Plan (FileFlow)

on:
  pull_request:
    branches:
      - main
    paths:
      - 'infrastructure/terraform/**'

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  terraform-plan:
    name: Terraform Plan - ${{ matrix.environment }}
    runs-on: ubuntu-latest
    timeout-minutes: 10

    strategy:
      matrix:
        environment:
          - dev
          - staging
          - prod

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: ap-northeast-2

      - name: Terraform Init
        run: terraform init
        working-directory: infrastructure/terraform

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan \
            -var-file=environments/${{ matrix.environment }}/terraform.tfvars \
            -no-color \
            -out=plan-${{ matrix.environment }}.out
        working-directory: infrastructure/terraform

      - name: Comment PR
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan - ${{ matrix.environment }}\nPlan completed successfully. Check artifacts for details.`
            });
```

**파일**: `/path/to/fileflow/.github/workflows/deploy.yml`

```yaml
name: Deploy FileFlow

on:
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    name: Deploy to ${{ github.event.inputs.environment || 'dev' }}
    runs-on: ubuntu-latest
    timeout-minutes: 30
    environment: ${{ github.event.inputs.environment || 'dev' }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: ap-northeast-2

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and Push Docker Image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: fileflow
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.0

      - name: Terraform Init
        run: terraform init
        working-directory: infrastructure/terraform

      - name: Terraform Apply
        env:
          TF_VAR_image_tag: ${{ github.sha }}
        run: |
          terraform apply \
            -var-file=environments/${{ github.event.inputs.environment || 'dev' }}/terraform.tfvars \
            -auto-approve
        working-directory: infrastructure/terraform

      - name: Update ECS Service
        run: |
          aws ecs update-service \
            --cluster fileflow-${{ github.event.inputs.environment || 'dev' }}-cluster \
            --service fileflow-${{ github.event.inputs.environment || 'dev' }}-service \
            --force-new-deployment \
            --region ap-northeast-2
```

### Atlantis 통합 (옵션)

Atlantis를 사용하여 PR 기반 Terraform 워크플로를 자동화할 수 있습니다.

**파일**: `atlantis.yaml`

```yaml
version: 3

projects:
  # Infrastructure 프로젝트
  - name: infrastructure-network
    dir: terraform/network
    workspace: default
    autoplan:
      when_modified:
        - "*.tf"
        - "*.tfvars"
    apply_requirements:
      - approved
      - mergeable

  - name: infrastructure-kms
    dir: terraform/kms
    workspace: default
    autoplan:
      when_modified:
        - "*.tf"
        - "*.tfvars"
    apply_requirements:
      - approved
      - mergeable

  # Application 프로젝트 (FileFlow)
  - name: fileflow-dev
    dir: infrastructure/terraform
    workspace: dev
    terraform_version: v1.9.0
    autoplan:
      when_modified:
        - "*.tf"
        - "environments/dev/*.tfvars"
    apply_requirements:
      - approved

  - name: fileflow-prod
    dir: infrastructure/terraform
    workspace: prod
    terraform_version: v1.9.0
    autoplan:
      when_modified:
        - "*.tf"
        - "environments/prod/*.tfvars"
    apply_requirements:
      - approved
      - mergeable

workflows:
  default:
    plan:
      steps:
        - init
        - plan:
            extra_args: ["-lock=false"]
    apply:
      steps:
        - apply
```

### PR 자동화 전략

#### 1. PR 생성 시 자동 실행
- Terraform fmt check
- Terraform validate
- Terraform plan (환경별)
- Security scan (tfsec, checkov)
- Cost analysis (Infracost)

#### 2. PR 승인 및 Merge 시
- Terraform apply
- Docker image build & push (Application 프로젝트)
- ECS service update

#### 3. 배포 승인 프로세스

**환경별 승인 전략**:

| 환경 | 승인 필요 | 승인자 | 배포 시간 |
|------|----------|--------|----------|
| **Dev** | ❌ 자동 | - | PR Merge 즉시 |
| **Staging** | ✅ 필요 | Platform Team | 영업시간 내 |
| **Prod** | ✅ 필요 | Platform Lead + CTO | 화/목 오전 10시 |

**GitHub Environment 설정**:

```yaml
# .github/workflows/deploy.yml
environment: production
  approval_required: true
  reviewers:
    - platform-team
    - cto
  wait_timer: 0  # 승인 후 즉시 배포
```

---

## 모니터링 및 로깅

### CloudWatch Logs 통합

#### Log Group 구조

```
/ecs/[service]-[env]/application       # 애플리케이션 로그
/ecs/[service]-[env]/access           # 액세스 로그 (ALB)
/ecs/[service]-[env]/error            # 에러 로그
/aws/lambda/[service]-[env]           # Lambda 로그 (있는 경우)
```

#### Terraform 설정

**파일**: `cloudwatch-logs.tf`

```hcl
# Application Log Group
resource "aws_cloudwatch_log_group" "application" {
  name              = "/ecs/${var.service}-${var.env}/application"
  retention_in_days = var.env == "prod" ? 14 : 7
  kms_key_id        = local.cloudwatch_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.service}-${var.env}-app-logs"
      Component = "logging"
    }
  )
}

# Error Log Group
resource "aws_cloudwatch_log_group" "error" {
  name              = "/ecs/${var.service}-${var.env}/error"
  retention_in_days = var.env == "prod" ? 30 : 14
  kms_key_id        = local.cloudwatch_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.service}-${var.env}-error-logs"
      Component = "logging"
    }
  )
}
```

### X-Ray 트레이싱 설정

#### ECS Task Definition에 X-Ray 컨테이너 추가

```hcl
# ecs.tf
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.service}-${var.env}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "${var.service}-app"
      image     = "${local.ecr_repository_url}:${var.image_tag}"
      essential = true

      environment = [
        {
          name  = "AWS_XRAY_DAEMON_ADDRESS"
          value = "xray-daemon:2000"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.application.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "xray-daemon"
      image     = "amazon/aws-xray-daemon:latest"
      essential = false
      cpu       = 32
      memory    = 256

      portMappings = [
        {
          containerPort = 2000
          protocol      = "udp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.application.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "xray"
        }
      }
    }
  ])
}
```

### Application Insights 설정

```hcl
# application-insights.tf
resource "aws_applicationinsights_application" "app" {
  resource_group_name = aws_resourcegroups_group.app.name
  auto_config_enabled = true
  auto_create         = true

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.service}-${var.env}-insights"
      Component = "monitoring"
    }
  )
}

resource "aws_resourcegroups_group" "app" {
  name = "${var.service}-${var.env}-resources"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = [
        "AWS::ECS::Service",
        "AWS::RDS::DBInstance",
        "AWS::ElastiCache::ReplicationGroup",
        "AWS::ElasticLoadBalancingV2::LoadBalancer"
      ]
      TagFilters = [
        {
          Key    = "Service"
          Values = [var.service]
        },
        {
          Key    = "Environment"
          Values = [var.env]
        }
      ]
    })
  }
}
```

### 메트릭 및 알람 설정

#### 표준 메트릭

**파일**: `cloudwatch-alarms.tf`

```hcl
# ECS Service CPU Utilization
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.service}-${var.env}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = local.required_tags
}

# ECS Service Memory Utilization
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.service}-${var.env}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "ECS Memory utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = local.required_tags
}

# ALB 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.service}-${var.env}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB is returning too many 5xx errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.required_tags
}

# RDS CPU Utilization
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count               = var.use_shared_rds ? 0 : 1
  alarm_name          = "${var.service}-${var.env}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main[0].id
  }

  tags = local.required_tags
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.service}-${var.env}-alerts"
  kms_master_key_id = local.secrets_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.service}-${var.env}-alerts"
      Component = "monitoring"
    }
  )
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "alerts_slack" {
  count     = var.slack_webhook_url != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier[0].arn
}
```

### 로그 집계 및 분석

#### S3로 로그 Export

```bash
# 스크립트: scripts/export-logs-to-s3.sh
#!/bin/bash

LOG_GROUP="/ecs/fileflow-prod/application"
FROM_TIME=$(date -u -d '7 days ago' +%s)000
TO_TIME=$(date -u +%s)000
BUCKET="fileflow-prod-logs-archive"
PREFIX="cloudwatch-logs/$(date -u +%Y/%m/%d)"

aws logs create-export-task \
  --log-group-name "$LOG_GROUP" \
  --from $FROM_TIME \
  --to $TO_TIME \
  --destination "$BUCKET" \
  --destination-prefix "$PREFIX" \
  --region ap-northeast-2
```

#### CloudWatch Insights 쿼리 예제

```
# 최근 1시간 에러 로그
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100

# API 응답 시간 분석
fields @timestamp, responseTime
| filter @message like /API/
| stats avg(responseTime), max(responseTime), min(responseTime) by bin(5m)

# 5xx 에러 패턴 분석
fields @timestamp, @message, statusCode
| filter statusCode >= 500
| stats count() by statusCode, bin(1h)
```

---

## 비용 예측 및 최적화

### 환경별 예상 비용

#### Dev 환경 (월 예상 비용: $150~$200)

| 리소스 | 스펙 | 수량 | 월 비용 (USD) |
|--------|------|------|---------------|
| **ECS Fargate** | 512 CPU / 1GB RAM | 1 task, 24/7 | $30 |
| **ALB** | Application Load Balancer | 1 | $20 |
| **ElastiCache Redis** | cache.t3.micro | 1 node | $15 |
| **S3** | Standard storage | ~100GB | $3 |
| **CloudWatch Logs** | 7-day retention | ~50GB/month | $25 |
| **NAT Gateway** | Data transfer | ~100GB | $50 |
| **Secrets Manager** | Active secrets | 5 secrets | $2 |
| **SSM Parameters** | Standard parameters | Free | $0 |
| **합계** | | | **$145** |

#### Staging 환경 (월 예상 비용: $300~$400)

| 리소스 | 스펙 | 수량 | 월 비용 (USD) |
|--------|------|------|---------------|
| **ECS Fargate** | 1024 CPU / 2GB RAM | 2 tasks, 24/7 | $120 |
| **ALB** | Application Load Balancer | 1 | $20 |
| **ElastiCache Redis** | cache.t3.small | 1 node | $30 |
| **S3** | Standard storage | ~200GB | $5 |
| **CloudWatch Logs** | 14-day retention | ~100GB/month | $50 |
| **NAT Gateway** | Data transfer | ~200GB | $95 |
| **Secrets Manager** | Active secrets | 5 secrets | $2 |
| **합계** | | | **$322** |

#### Prod 환경 (월 예상 비용: $600~$800)

| 리소스 | 스펙 | 수량 | 월 비용 (USD) |
|--------|------|------|---------------|
| **ECS Fargate** | 2048 CPU / 4GB RAM | 3-5 tasks, 24/7 | $250 |
| **ALB** | Application Load Balancer | 1 | $25 |
| **ElastiCache Redis** | cache.t3.medium, Multi-AZ | 2 nodes | $85 |
| **S3** | Standard + IA + Glacier | ~500GB | $15 |
| **CloudWatch Logs** | 14-day retention | ~200GB/month | $100 |
| **NAT Gateway** | Data transfer, Multi-AZ | ~500GB | $180 |
| **Secrets Manager** | Active secrets | 8 secrets | $3 |
| **X-Ray** | Traces | ~1M requests | $5 |
| **합계** | | | **$663** |

#### 공유 인프라 (모든 서비스가 공유, 월 예상 비용: $400~$500)

| 리소스 | 스펙 | 수량 | 월 비용 (USD) |
|--------|------|------|---------------|
| **VPC** | NAT Gateway (Multi-AZ) | 2 gateways | $65 |
| **KMS** | Customer-managed keys | 7 keys | $7 |
| **Shared RDS** | db.t3.large, Multi-AZ | 1 instance | $280 |
| **ECR** | Image storage | ~50GB | $5 |
| **CloudTrail** | Log storage and events | Standard | $15 |
| **합계** | | | **$372** |

**참고**: 공유 인프라 비용은 여러 서비스가 나누어 부담합니다 (예: 3개 서비스 → 서비스당 $124).

### 비용 최적화 전략

#### 1. Compute 최적화

**ECS Fargate Spot 사용** (Dev/Staging 환경):
```hcl
# ecs.tf
resource "aws_ecs_service" "app" {
  # ... other configuration ...

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
    base              = 0
  }

  # 비용 절감: 최대 70%
}
```

**적절한 Task 크기 선택**:
```hcl
# 과도한 크기 (비효율)
ecs_task_cpu    = 4096  # 4 vCPU
ecs_task_memory = 8192  # 8 GB
# 월 비용: ~$500

# 적정 크기 (효율적)
ecs_task_cpu    = 1024  # 1 vCPU
ecs_task_memory = 2048  # 2 GB
# 월 비용: ~$120
# 절감: $380/월 (76%)
```

#### 2. Storage 최적화

**S3 Lifecycle 정책**:
```hcl
# s3.tf
resource "aws_s3_bucket_lifecycle_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    id     = "archive-old-files"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"  # 비용 46% 절감
    }

    transition {
      days          = 365
      storage_class = "GLACIER"  # 비용 80% 절감
    }

    expiration {
      days = 2555  # 7년 후 삭제
    }
  }
}
```

**S3 Intelligent Tiering**:
```hcl
resource "aws_s3_bucket" "storage" {
  bucket = "${var.service}-${var.env}-storage"

  # 자동 tiering으로 15-40% 비용 절감
  lifecycle_rule {
    id      = "intelligent-tiering"
    enabled = true

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}
```

#### 3. Database 최적화

**Shared RDS 활용**:
```
전용 RDS (db.t3.medium, 3개 서비스):
- 서비스당 비용: $140/월
- 총 비용: $420/월

Shared RDS (db.t3.large, 3개 서비스 공유):
- 총 비용: $280/월
- 서비스당 비용: $93/월
- 절감: $140/월 (33%)
```

**Reserved Instances** (Prod 환경):
```
On-Demand RDS (db.t3.large):
- 월 비용: $140

1-Year Reserved (No Upfront):
- 월 비용: $98
- 절감: $42/월 (30%)

3-Year Reserved (All Upfront):
- 월 비용: $75
- 절감: $65/월 (46%)
```

#### 4. 네트워크 최적화

**VPC Endpoints 사용** (NAT Gateway 비용 절감):
```hcl
# network.tf
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-northeast-2.s3"

  tags = merge(
    local.required_tags,
    {
      Name      = "s3-gateway-endpoint"
      Component = "network"
    }
  )
}

# S3 트래픽이 NAT Gateway를 거치지 않음
# 월 절감: ~$20-30 (트래픽에 따라)
```

**NAT Gateway 최적화**:
```
Multi-AZ NAT Gateway (고가용성):
- 비용: $65/월 (2 gateways)
- 용도: Production 환경

Single NAT Gateway (비용 절감):
- 비용: $32.5/월 (1 gateway)
- 용도: Dev/Staging 환경
- 절감: $32.5/월 (50%)
```

#### 5. 로깅 최적화

**CloudWatch Logs 보존 기간 최적화**:
```hcl
# Dev: 7일 → 월 $25
retention_in_days = 7

# Staging: 14일 → 월 $50
retention_in_days = 14

# Prod: 14일 (CloudWatch) + S3 아카이브 → 월 $115
retention_in_days = 14  # $100
# S3 archive (7년): $15
```

### Infracost 통합

**파일**: `.github/workflows/infracost.yml`

```yaml
name: Infracost

on:
  pull_request:
    branches:
      - main
    paths:
      - 'terraform/**'

permissions:
  contents: read
  pull-requests: write

jobs:
  infracost:
    name: Infracost Analysis
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Infracost
        uses: infracost/actions/setup@v2
        with:
          api-key: ${{ secrets.INFRACOST_API_KEY }}

      - name: Generate Infracost JSON
        run: |
          infracost breakdown --path=terraform \
            --format=json \
            --out-file=/tmp/infracost.json

      - name: Post Infracost comment
        uses: infracost/actions/comment@v1
        with:
          path: /tmp/infracost.json
          behavior: update
```

**비용 임계값 설정**:
```yaml
# 월 비용 증가가 10% 이상이면 경고, 30% 이상이면 차단
- name: Check cost increase
  run: |
    COST_DIFF=$(jq '.diffTotalMonthlyCost' /tmp/infracost.json)
    if (( $(echo "$COST_DIFF > 100" | bc -l) )); then
      echo "::error::Cost increase is too high: \$$COST_DIFF/month"
      exit 1
    fi
```

---

## 운영 가이드

### Rollback 절차

#### 1. Terraform State Rollback

**시나리오**: 잘못된 Terraform 변경 적용 후 이전 상태로 복구

```bash
# 1. 현재 State 백업
terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate

# 2. State 버전 확인
aws s3api list-object-versions \
  --bucket ryuqqq-prod-tfstate \
  --prefix fileflow/terraform.tfstate \
  --region ap-northeast-2

# 3. 이전 버전으로 복구
aws s3api get-object \
  --bucket ryuqqq-prod-tfstate \
  --key fileflow/terraform.tfstate \
  --version-id <previous-version-id> \
  terraform.tfstate.restored

# 4. State 교체
terraform state push terraform.tfstate.restored

# 5. Plan 실행하여 diff 확인
terraform plan -var-file=environments/prod/terraform.tfvars

# 6. Apply 실행
terraform apply -var-file=environments/prod/terraform.tfvars
```

#### 2. Database 마이그레이션 Rollback

**시나리오**: Database schema 변경 실패 후 롤백

```bash
# 1. 사전 백업 확인
aws rds describe-db-snapshots \
  --db-instance-identifier prod-shared-mysql \
  --region ap-northeast-2 \
  --query 'DBSnapshots[0]'

# 2. 마이그레이션 실패 시 롤백 SQL 실행
mysql -h prod-shared-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com \
      -u admin -p fileflow < rollback/V002__rollback.sql

# 3. 데이터 정합성 확인
mysql -h prod-shared-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com \
      -u admin -p fileflow -e "SELECT COUNT(*) FROM critical_table;"

# 4. 스냅샷에서 복구 (최악의 경우)
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prod-shared-mysql-restored \
  --db-snapshot-identifier fileflow-pre-migration-20251022 \
  --region ap-northeast-2
```

#### 3. ECS Task 이전 버전 복구

**시나리오**: 새 버전 배포 후 문제 발생, 이전 이미지로 롤백

```bash
# 1. 이전 Task Definition 확인
aws ecs list-task-definitions \
  --family-prefix fileflow-prod \
  --region ap-northeast-2 \
  --query 'taskDefinitionArns[-2:]'

# 2. 이전 Task Definition으로 서비스 업데이트
aws ecs update-service \
  --cluster fileflow-prod-cluster \
  --service fileflow-prod-service \
  --task-definition fileflow-prod:42 \
  --force-new-deployment \
  --region ap-northeast-2

# 3. 배포 상태 모니터링
aws ecs describe-services \
  --cluster fileflow-prod-cluster \
  --services fileflow-prod-service \
  --region ap-northeast-2 \
  --query 'services[0].deployments'

# 4. 이전 이미지 태그로 재배포 (Terraform)
terraform apply \
  -var-file=environments/prod/terraform.tfvars \
  -var="image_tag=abc123def" \
  -auto-approve
```

#### 4. 긴급 상황 대응 절차

**체크리스트**:

- [ ] **사고 인지 및 선언**
  - Slack #incidents 채널에 알림
  - PagerDuty 또는 온콜 시스템 트리거
  - 사고 심각도 평가 (P0/P1/P2/P3)

- [ ] **즉각적인 완화 조치**
  - 트래픽 차단 (WAF rule, Security Group 수정)
  - 문제 서비스 scale down
  - 이전 버전으로 롤백

- [ ] **근본 원인 파악**
  - CloudWatch Logs 분석
  - X-Ray traces 확인
  - Database slow query 로그
  - 최근 변경 사항 검토

- [ ] **복구 실행**
  - Rollback 절차 실행
  - 데이터 정합성 확인
  - Health check 통과 확인

- [ ] **사후 분석 (Postmortem)**
  - Timeline 작성
  - Root cause 문서화
  - Action items 도출
  - Confluence에 Postmortem 문서 작성

### 다중 리전 전략 (DR)

#### DR 환경 설정 (ap-northeast-1)

**목표 RTO/RPO**:
- RTO (Recovery Time Objective): 2시간
- RPO (Recovery Point Objective): 15분

**Architecture**:
```
Primary Region (ap-northeast-2):
- 모든 리소스 Active
- RDS: Multi-AZ, Automated Backups
- S3: Cross-Region Replication

DR Region (ap-northeast-1):
- VPC, Subnets (Pre-provisioned)
- KMS Keys (Pre-provisioned)
- RDS: Read Replica (Standby)
- ECS: Task Definition only (Standby)
- S3: Replication Target
```

#### Terraform 설정

**파일**: `terraform/dr/main.tf`

```hcl
# DR Region Provider
provider "aws" {
  alias  = "dr"
  region = "ap-northeast-1"
}

# DR VPC (미리 프로비저닝)
module "dr_network" {
  source = "../../modules/network"

  providers = {
    aws = aws.dr
  }

  env        = "prod-dr"
  cidr_block = "10.1.0.0/16"  # 다른 CIDR 사용
}

# RDS Read Replica (DR 준비)
resource "aws_db_instance" "read_replica" {
  provider               = aws.dr
  replicate_source_db    = aws_db_instance.primary.arn
  instance_class         = "db.t3.large"
  identifier             = "prod-shared-mysql-replica"
  multi_az               = true
  publicly_accessible    = false
  backup_retention_period = 7

  tags = merge(
    local.required_tags,
    {
      Name        = "prod-shared-mysql-replica"
      Environment = "prod-dr"
      Region      = "ap-northeast-1"
    }
  )
}

# S3 Cross-Region Replication
resource "aws_s3_bucket_replication_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id
  role   = aws_iam_role.s3_replication.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.storage_dr.arn
      storage_class = "STANDARD_IA"

      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }

      metrics {
        status = "Enabled"
        event_threshold {
          minutes = 15
        }
      }
    }
  }
}

# DR 환경 S3 Bucket
resource "aws_s3_bucket" "storage_dr" {
  provider = aws.dr
  bucket   = "${var.service}-${var.env}-storage-dr"

  tags = merge(
    local.required_tags,
    {
      Name        = "${var.service}-${var.env}-storage-dr"
      Environment = "prod-dr"
      Region      = "ap-northeast-1"
    }
  )
}
```

#### DR Failover 절차

```bash
#!/bin/bash
# scripts/dr-failover.sh

set -e

DR_REGION="ap-northeast-1"
PRIMARY_REGION="ap-northeast-2"

echo "Starting DR failover to $DR_REGION..."

# 1. RDS Read Replica를 Primary로 승격
echo "Promoting RDS Read Replica..."
aws rds promote-read-replica \
  --db-instance-identifier prod-shared-mysql-replica \
  --region $DR_REGION

# 2. Route53 DNS 레코드 변경
echo "Updating Route53 DNS records..."
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://dns-failover.json

# 3. DR Region에 ECS Service 배포
echo "Deploying ECS Service to DR region..."
cd terraform/dr
terraform init
terraform apply \
  -var-file=environments/prod-dr/terraform.tfvars \
  -auto-approve

# 4. Health check 확인
echo "Waiting for health checks..."
sleep 60

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --region $DR_REGION \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS/actuator/health)

if [ "$HTTP_CODE" == "200" ]; then
  echo "✅ DR failover completed successfully"
else
  echo "❌ Health check failed: HTTP $HTTP_CODE"
  exit 1
fi

echo "DR Environment is now serving traffic"
```

#### 리전 간 VPC Peering

```hcl
# VPC Peering Connection
resource "aws_vpc_peering_connection" "primary_to_dr" {
  vpc_id        = module.network.vpc_id
  peer_vpc_id   = module.dr_network.vpc_id
  peer_region   = "ap-northeast-1"
  auto_accept   = false

  tags = merge(
    local.required_tags,
    {
      Name = "primary-to-dr-peering"
      Side = "Requester"
    }
  )
}

# DR Region에서 Peering 수락
resource "aws_vpc_peering_connection_accepter" "dr" {
  provider                  = aws.dr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_dr.id
  auto_accept               = true

  tags = merge(
    local.required_tags,
    {
      Name = "primary-to-dr-peering"
      Side = "Accepter"
    }
  )
}

# Route Table 업데이트
resource "aws_route" "primary_to_dr" {
  route_table_id            = module.network.private_route_table_id
  destination_cidr_block    = "10.1.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_dr.id
}

resource "aws_route" "dr_to_primary" {
  provider                  = aws.dr
  route_table_id            = module.dr_network.private_route_table_id
  destination_cidr_block    = "10.0.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_dr.id
}
```

#### 글로벌 리소스 관리

**Route53**:
```hcl
# Hosted Zone
resource "aws_route53_zone" "main" {
  name = "fileflow.ryuqqq.com"

  tags = local.required_tags
}

# Primary Region ALB Record (Active)
resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.fileflow.ryuqqq.com"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }

  set_identifier = "primary"

  failover_routing_policy {
    type = "PRIMARY"
  }
}

# DR Region ALB Record (Standby)
resource "aws_route53_record" "dr" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.fileflow.ryuqqq.com"
  type    = "A"

  alias {
    name                   = aws_lb.dr.dns_name
    zone_id                = aws_lb.dr.zone_id
    evaluate_target_health = true
  }

  set_identifier = "dr"

  failover_routing_policy {
    type = "SECONDARY"
  }
}

# Health Check
resource "aws_route53_health_check" "primary" {
  fqdn              = aws_lb.main.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/actuator/health"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(
    local.required_tags,
    {
      Name = "fileflow-prod-health-check"
    }
  )
}
```

**CloudFront** (글로벌 CDN):
```hcl
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "FileFlow CDN"
  default_root_object = "index.html"

  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "primary-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin_group {
    origin_id = "primary-with-failover"

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }

    member {
      origin_id = "primary-alb"
    }

    member {
      origin_id = "dr-alb"
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "primary-with-failover"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.main.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = local.required_tags
}
```

---

## 트러블슈팅

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
```

---

## 모범 사례

### 명명 규칙

#### SSM Parameter 경로
```
/shared/{category}/{resource-name}

예제:
/shared/network/vpc-id
/shared/kms/s3-key-arn
/shared/ecr/fileflow-repository-url
/shared/rds/prod/identifier
```

#### Shared RDS 인스턴스
```
{environment}-shared-mysql

예제:
dev-shared-mysql
staging-shared-mysql
prod-shared-mysql
```

#### Database 이름
```
{service-name}

예제:
fileflow
authhub
crawler

# 짧고 명확하게 (특수문자 없이)
```

#### Database 사용자
```
{service-name}_user

예제:
fileflow_user
authhub_user
crawler_user
```

#### 리소스 네이밍
```
{service-name}-{environment}-{resource-type}

예제:
fileflow-prod-cluster
fileflow-prod-ecs-tasks-sg
fileflow-prod-storage-bucket
```

### 보안

#### Secrets 관리
- ✅ **Secrets Manager 사용**: 모든 민감 정보 (DB 패스워드, API 키)
- ✅ **KMS 암호화**: Secrets Manager에 KMS key 지정
- ❌ **하드코딩 금지**: Terraform 코드나 환경 변수에 패스워드 하드코딩 금지
- ✅ **최소 권한**: IAM 정책은 필요한 권한만 부여
- ✅ **Rotation**: Secrets Manager automatic rotation 활성화 (가능 시)

#### KMS Key 정책
- ✅ **리소스별 분리**: CloudWatch, S3, SQS, RDS 등 전용 키 사용
- ✅ **Key Rotation**: `enable_key_rotation = true`
- ✅ **Deletion Protection**: `deletion_window_in_days = 30` (prod)
- ✅ **Principal 명시**: 서비스별 principal 명확히 지정

#### Security Group
- ✅ **최소 권한**: 필요한 포트만 개방
- ✅ **소스 제한**: CIDR 대신 Security Group ID 참조
- ✅ **설명 추가**: 각 규칙에 `description` 추가
- ❌ **0.0.0.0/0 지양**: 불필요한 전역 개방 금지

#### IAM 역할
- ✅ **최소 권한 원칙**: 필요한 권한만 부여
- ✅ **리소스 ARN 명시**: `"Resource": "*"` 지양
- ✅ **조건 추가**: 가능한 경우 `Condition` 블록 사용
- ✅ **역할 분리**: Execution Role과 Task Role 분리

### 비용 최적화

#### Shared RDS 활용
- ✅ **멀티 테넌트**: 여러 서비스가 하나의 RDS 인스턴스 공유
- ✅ **적절한 인스턴스 크기**: 환경별 인스턴스 크기 조정
  - Dev: `db.t3.small`
  - Staging: `db.t3.medium`
  - Prod: `db.t3.large` ~ `db.r6g.xlarge`
- ✅ **Storage Auto Scaling**: `max_allocated_storage` 설정
- ❌ **과도한 백업 보관 지양**: 백업 보관 기간 적절히 설정 (7일)

#### ECS Auto Scaling
- ✅ **Target Tracking**: CPU/Memory 기반 Auto Scaling
- ✅ **환경별 범위**: Dev는 1~3, Prod는 2~10
- ✅ **Scale-in 보호**: Prod 환경에서 최소 태스크 수 유지

#### S3 Lifecycle
- ✅ **Lifecycle Rules**: 오래된 파일 자동 아카이빙
  - 90일: Standard → Standard-IA
  - 365일: Standard-IA → Glacier
  - 7년: Glacier → Expiration
- ✅ **Intelligent Tiering**: 액세스 패턴에 따라 자동 이동

#### CloudWatch Logs
- ✅ **보존 기간 설정**: 7~14일 (환경별)
- ✅ **S3 Export**: 장기 보관이 필요한 로그는 S3로 Export
- ❌ **무제한 보관 지양**: 비용 증가 원인

### 유지보수성

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

#### 모듈화
- ✅ **재사용 가능한 모듈**: 공통 패턴 모듈화
- ✅ **버전 관리**: 모듈 버전 명시 (`version = "1.0.0"`)
- ✅ **문서화**: 각 모듈에 `README.md` 추가
- ✅ **예제 제공**: `examples/` 디렉토리에 사용 예제

#### 문서화
- ✅ **README.md**: 프로젝트 개요, 배포 방법
- ✅ **CHANGELOG.md**: 버전별 변경 사항
- ✅ **아키텍처 다이어그램**: ASCII art 또는 이미지
- ✅ **트러블슈팅 가이드**: 자주 발생하는 문제 해결 방법

### Git 워크플로

#### 브랜치 전략
```
main (production)
├── develop (staging)
│   ├── feature/KAN-XXX-description
│   └── hotfix/KAN-YYY-description
```

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

#### Pull Request 체크리스트
- [ ] `terraform fmt -recursive` 실행
- [ ] `terraform validate` 통과
- [ ] `terraform plan` 검토 완료
- [ ] 보안 스캔 통과 (tfsec, checkov)
- [ ] 주석 및 문서 업데이트
- [ ] 관련 Jira 태스크 링크

---

## FAQ

### Q: 언제 Shared RDS를 사용하고 언제 전용 RDS를 사용해야 하나요?

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

### Q: SSM Parameter vs Terraform Remote State, 어떤 것을 사용해야 하나요?

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

**Remote State 예제** (권장하지 않음):
```hcl
# Application 프로젝트
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "tfstate-bucket"
    key    = "network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
}
```

### Q: 여러 환경(dev/staging/prod)을 어떻게 관리하나요?

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

### Q: 기존 전용 RDS를 Shared RDS로 마이그레이션하려면?

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

### Q: SSM Parameter가 변경되면 Application Terraform에 어떻게 반영되나요?

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

### Q: 하나의 Application 프로젝트에서 여러 서비스를 관리할 수 있나요?

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

### Q: Terraform Module을 Infrastructure 프로젝트에서 참조하려면?

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

## 실제 프로젝트 구조

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
│   │   ├── hybrid-infrastructure-setup-guide.md  # 이 문서
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
├── FILEFLOW_HYBRID_MIGRATION.md
├── FILEFLOW_MIGRATION_CHECKPOINT.md
├── .tfsec/
│   └── config.yml
├── .checkov.yml
└── atlantis.yaml
```

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

## 참고 자료

### 내부 문서
- **Infrastructure 프로젝트**: `/path/to/infrastructure/CLAUDE.md`
- **FileFlow 마이그레이션 계획**: `/path/to/infrastructure/FILEFLOW_HYBRID_MIGRATION.md`
- **FileFlow 마이그레이션 체크포인트**: `/path/to/infrastructure/FILEFLOW_MIGRATION_CHECKPOINT.md`
- **Governance 가이드**: `/path/to/infrastructure/docs/governance/`

### Terraform 모듈
- **공통 모듈**: `/path/to/infrastructure/terraform/modules/`
- **모듈 개발 가이드**: `/path/to/infrastructure/docs/modules/`

### 실제 구현 예제
- **FileFlow 프로젝트**: `/path/to/fileflow/infrastructure/terraform/`
- **Infrastructure 백업**: `/path/to/infrastructure/terraform/fileflow.backup-20251021-094557/`

### AWS 공식 문서
- **SSM Parameter Store**: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html
- **KMS**: https://docs.aws.amazon.com/kms/latest/developerguide/overview.html
- **RDS**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html
- **ECS**: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html

### Terraform 공식 문서
- **AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **Data Sources**: https://www.terraform.io/language/data-sources
- **Modules**: https://www.terraform.io/language/modules

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|-----|------|----------|--------|
| 1.0 | 2025-10-21 | 초기 작성 | Platform Team |
| 1.1 | 2025-10-22 | 주요 섹션 추가: 빠른 시작 가이드, 기술 스택 요구사항, CI/CD 통합, 모니터링/로깅, 비용 예측, 운영 가이드 (Rollback, DR), 실제 프로젝트 구조 | Platform Team (Claude Code) |

### 버전 1.1 주요 추가 사항

#### 1. 빠른 시작 가이드 (Phase 1-6)
- 초기 설정 체크리스트 (Infrastructure 준비, SSM Parameters 검증)
- Application 프로젝트 설정 (디렉토리 구조, tfvars 파일)
- 첫 배포 실행 (Terraform init/plan/apply)
- 검증 테스트 (네트워크, Database, Secrets Manager, S3, SQS, CloudWatch)
- 문서화 및 마무리

#### 2. 기술 스택 및 버전 요구사항
- 필수 도구 및 최소 버전: Terraform (>= 1.5.0), AWS CLI (>= 2.0), MySQL Client, jq
- AWS Provider 버전: >= 5.50.0
- 운영체제 호환성: macOS, Ubuntu, Debian, Amazon Linux, Windows (WSL2)
- AWS 권한 및 IAM 정책 (Infrastructure/Application 프로젝트별)
- 네트워크 요구사항 (아웃바운드 도메인, 방화벽 포트)

#### 3. CI/CD 통합
- GitHub Actions 워크플로 (Infrastructure 프로젝트: terraform-plan.yml, terraform-apply.yml)
- Application 프로젝트 워크플로 (terraform-plan.yml, deploy.yml)
- Atlantis 통합 (atlantis.yaml 설정)
- PR 자동화 전략 (PR 생성 시, Merge 시, 배포 승인 프로세스)
- 환경별 승인 전략 (Dev/Staging/Prod)

#### 4. 모니터링 및 로깅
- CloudWatch Logs 통합 (Log Group 구조, Terraform 설정)
- X-Ray 트레이싱 설정 (ECS Task Definition에 X-Ray 컨테이너 추가)
- Application Insights 설정
- 메트릭 및 알람 설정 (ECS CPU/Memory, ALB 5xx, RDS CPU, SNS Topic)
- 로그 집계 및 분석 (S3 Export, CloudWatch Insights 쿼리 예제)

#### 5. 비용 예측 및 최적화
- 환경별 예상 비용 (Dev: $150, Staging: $320, Prod: $660, 공유 인프라: $370)
- 비용 최적화 전략
  - Compute: ECS Fargate Spot, 적절한 Task 크기
  - Storage: S3 Lifecycle, Intelligent Tiering
  - Database: Shared RDS 활용, Reserved Instances
  - Network: VPC Endpoints, NAT Gateway 최적화
  - Logging: CloudWatch Logs 보존 기간 최적화
- Infracost 통합 (infracost.yml, 비용 임계값 설정)

#### 6. 운영 가이드
- Rollback 절차
  - Terraform State Rollback
  - Database 마이그레이션 Rollback
  - ECS Task 이전 버전 복구
  - 긴급 상황 대응 체크리스트
- 다중 리전 전략 (DR)
  - DR 환경 설정 (ap-northeast-1)
  - RTO/RPO 목표 (2시간/15분)
  - Terraform 설정 (DR VPC, RDS Read Replica, S3 Cross-Region Replication)
  - DR Failover 절차 (스크립트)
  - 리전 간 VPC Peering
  - 글로벌 리소스 관리 (Route53, CloudFront)

#### 7. 실제 프로젝트 구조
- Infrastructure 프로젝트 Tree 구조 (18개 주요 디렉토리)
- Application 프로젝트 Tree 구조 (FileFlow 예시)
- 주요 파일 설명 및 중요도 (⭐⭐⭐⭐⭐)

---

**문서 피드백**: 이 가이드에 대한 피드백이나 개선 제안은 Jira 또는 Slack #infrastructure 채널로 부탁드립니다.
