# 하이브리드 인프라 운영 가이드

**작성일**: 2025-10-22
**버전**: 1.0
**대상 독자**: SRE, 운영팀, DevOps 엔지니어
**소요 시간**: 40분

**선행 문서**:
- [Part 1: 개요 및 시작하기](hybrid-01-overview.md)
- [Part 2: 아키텍처 설계](hybrid-02-architecture-design.md)
- [Part 3: Infrastructure 프로젝트 설정](hybrid-03-infrastructure-setup.md)
- [Part 4: Application 프로젝트 설정](hybrid-04-application-setup.md)
- [Part 5: 배포 가이드](hybrid-05-deployment-guide.md)
- [Part 6: 모니터링 가이드](hybrid-06-monitoring-guide.md)

---

## 목차

1. [비용 예측 및 최적화](#1-비용-예측-및-최적화)
   - [환경별 예상 비용](#11-환경별-예상-비용)
   - [비용 최적화 전략](#12-비용-최적화-전략)
   - [Infracost 통합](#13-infracost-통합)

2. [Rollback 절차](#2-rollback-절차)
   - [Terraform State Rollback](#21-terraform-state-rollback)
   - [Database Migration Rollback](#22-database-migration-rollback)
   - [ECS Task Rollback](#23-ecs-task-rollback)
   - [긴급 대응 프로세스](#24-긴급-대응-프로세스)

3. [다중 리전 전략 (DR)](#3-다중-리전-전략-dr)
   - [DR 아키텍처 개요](#31-dr-아키텍처-개요)
   - [RTO/RPO 목표](#32-rtorpo-목표)
   - [DR 환경 구축](#33-dr-환경-구축)
   - [Failover 시나리오](#34-failover-시나리오)

4. [검증 및 모니터링](#4-검증-및-모니터링)

---

## 1. 비용 예측 및 최적화

### 1.1 환경별 예상 비용

하이브리드 인프라의 월간 예상 비용입니다 (2025년 10월 기준, ap-northeast-2 리전).

#### Dev 환경

| 서비스 | 사양 | 월간 비용 |
|--------|------|-----------|
| **ECS Fargate** | 0.25 vCPU, 0.5GB RAM, 1 task | $11 |
| **ALB** | 기본 ALB + 처리량 | $23 |
| **ElastiCache Redis** | cache.t3.micro (0.5GB) | $12 |
| **CloudWatch Logs** | 5GB/월 수집 + 7일 보관 | $3 |
| **X-Ray** | 100K traces/월 | $1 |
| **S3** | 10GB Standard | $0.25 |
| **SQS** | 1M requests/월 | $0.40 |
| **Secrets Manager** | 5개 secret | $2 |
| **NAT Gateway** | 데이터 전송 포함 | $45 |
| **VPC Endpoints** | S3 (Gateway, 무료) + ECR/Secrets (Interface) | $14 |
| **Route53** | Hosted Zone + Health Checks | $1 |
| **데이터 전송** | 인터넷 아웃바운드 50GB | $4.50 |
| **CloudWatch Alarms** | 10개 알람 | $1 |
| **기타** (CloudTrail, Config 등) | | $3 |
| **합계** | | **~$145/월** |

#### Staging 환경

| 서비스 | 사양 | 월간 비용 |
|--------|------|-----------|
| **ECS Fargate** | 0.5 vCPU, 1GB RAM, 2 tasks | $44 |
| **ALB** | 기본 ALB + 중간 처리량 | $35 |
| **ElastiCache Redis** | cache.t3.small (1.5GB) | $25 |
| **CloudWatch Logs** | 15GB/월 수집 + 14일 보관 | $8 |
| **X-Ray** | 500K traces/월 | $3 |
| **S3** | 50GB Standard + 20GB IA | $3 |
| **SQS** | 5M requests/월 | $2 |
| **Secrets Manager** | 8개 secret | $3.20 |
| **NAT Gateway** | 데이터 전송 포함 | $90 |
| **VPC Endpoints** | S3 + ECR + Secrets + DynamoDB | $21 |
| **Route53** | Hosted Zone + Health Checks | $2 |
| **데이터 전송** | 인터넷 아웃바운드 150GB | $13.50 |
| **CloudWatch Alarms** | 20개 알람 | $2 |
| **Application Insights** | 1 application | $5 |
| **기타** | | $5 |
| **합계** | | **~$322/월** |

#### Prod 환경

| 서비스 | 사양 | 월간 비용 |
|--------|------|-----------|
| **ECS Fargate** | 1 vCPU, 2GB RAM, 4 tasks (2 Spot + 2 On-Demand) | $132 (Spot 70% 할인 적용) |
| **ALB** | 기본 ALB + 고처리량 | $68 |
| **ElastiCache Redis** | cache.r6g.large (13.07GB), Multi-AZ | $120 |
| **CloudWatch Logs** | 50GB/월 수집 + 14일 보관 | $26 |
| **X-Ray** | 2M traces/월 | $10 |
| **S3** | 200GB Standard + 500GB IA + 1TB Glacier | $35 |
| **SQS** | 20M requests/월 | $8 |
| **Secrets Manager** | 15개 secret | $6 |
| **NAT Gateway** | 2 AZ, 데이터 전송 포함 | $180 |
| **VPC Endpoints** | S3 + ECR + Secrets + DynamoDB + SQS | $35 |
| **Route53** | Hosted Zone + Health Checks + Failover | $3 |
| **데이터 전송** | 인터넷 아웃바운드 500GB | $45 |
| **CloudWatch Alarms** | 40개 알람 | $4 |
| **Application Insights** | 1 application | $5 |
| **기타** (Config, CloudTrail, backups 등) | | $10 |
| **합계** | | **~$663/월** |

#### Shared Infrastructure (중앙 인프라)

| 서비스 | 사양 | 월간 비용 |
|--------|------|-----------|
| **RDS MySQL** | db.t3.medium, Multi-AZ, 100GB gp3 | $145 |
| **RDS Backups** | 200GB 백업 스토리지 | $20 |
| **KMS Keys** | 7개 Customer Managed Keys | $7 |
| **VPC** | Transit Gateway + Peering | $72 |
| **CloudTrail** | 관리 이벤트 로깅 | $2 |
| **Monitoring (AMP + AMG)** | Prometheus + Grafana | $85 |
| **S3 (Log Archive)** | 1TB Standard + 5TB Glacier | $45 |
| **기타** | | $5 |
| **합계** | | **~$372/월** |

**전체 합계** (Dev + Staging + Prod + Shared): **~$1,502/월** (~$18,024/년)

---

### 1.2 비용 최적화 전략

#### 전략 1: Fargate Spot 인스턴스 활용 (70% 비용 절감)

**개요**: ECS Fargate Spot을 사용하면 On-Demand 대비 최대 70% 비용 절감 가능.

**적용 방법**:

```hcl
# ecs.tf
resource "aws_ecs_service" "app" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 70
    base              = 0
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 30
    base              = 1  # 최소 1개는 On-Demand로 유지
  }

  # Spot 중단 시 graceful shutdown
  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }
}
```

**예상 절감**:
- Dev: $11 → $5 (월 $6 절감)
- Staging: $44 → $18 (월 $26 절감)
- Prod: $440 → $132 (월 $308 절감)

**주의사항**:
- Spot 인스턴스는 2분 전 중단 통보
- Stateful 서비스는 On-Demand 비율 높이기 (50:50 또는 30:70)
- Graceful shutdown 구현 필수 (SIGTERM 핸들링)

---

#### 전략 2: S3 Lifecycle 정책으로 스토리지 비용 80% 절감

**개요**: 로그 데이터를 Standard → IA → Glacier로 자동 전환하여 비용 절감.

**적용 방법**:

```hcl
# s3.tf
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log-lifecycle"
    status = "Enabled"

    # 90일 후 Infrequent Access로 전환
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    # 1년 후 Glacier로 전환
    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    # 7년 후 삭제 (컴플라이언스 요구사항에 따라 조정)
    expiration {
      days = 2555  # 7년
    }
  }

  rule {
    id     = "intelligent-tiering-for-access-logs"
    status = "Enabled"

    filter {
      prefix = "access-logs/"
    }

    # 자동으로 최적 스토리지 클래스 선택
    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}
```

**비용 비교** (1TB 데이터 기준):
- Standard (전체): $23/월
- Standard (90일) + IA (275일) + Glacier (7년): $4.50/월
- **절감**: 월 $18.50 (80% 절감)

---

#### 전략 3: Shared RDS로 Database 비용 50% 절감

**개요**: 여러 서비스가 하나의 RDS 인스턴스를 공유하고, 각 서비스는 별도 Database 및 User 사용.

**적용 방법**:

```hcl
# Infrastructure 프로젝트 - shared/rds/main.tf
resource "aws_db_instance" "shared" {
  identifier           = "ryuqqq-shared-rds"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.medium"
  allocated_storage    = 100
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id           = local.rds_key_arn
  multi_az             = true
  publicly_accessible  = false

  # 여러 Database 지원
  db_name              = "shared_db"  # 기본 DB (실제 사용 안 함)

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  performance_insights_enabled = true
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = merge(local.required_tags, {
    Name = "ryuqqq-shared-rds"
  })
}

# SSM Parameters 생성
resource "aws_ssm_parameter" "rds_endpoint" {
  name  = "/shared/rds/prod/endpoint"
  type  = "String"
  value = aws_db_instance.shared.endpoint
}
```

**Application 프로젝트에서 사용**:

```hcl
# Application 프로젝트 - database.tf
resource "null_resource" "create_database_and_user" {
  provisioner "local-exec" {
    command = <<-EOT
      mysql -h "$RDS_HOST" -u "$MASTER_USER" -p"$MASTER_PASS" << 'SQL'
        CREATE DATABASE IF NOT EXISTS ${var.db_name};
        CREATE USER IF NOT EXISTS '${var.db_username}'@'%' IDENTIFIED BY '${var.db_password}';
        GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
          ON ${var.db_name}.* TO '${var.db_username}'@'%';
        FLUSH PRIVILEGES;
      SQL
    EOT

    environment = {
      RDS_HOST      = local.shared_rds_endpoint
      MASTER_USER   = local.shared_rds_master_username
      MASTER_PASS   = local.shared_rds_master_password
    }
  }
}
```

**예상 절감**:
- 서비스당 별도 RDS (db.t3.micro × 5): $145 × 5 = $725/월
- Shared RDS (db.t3.medium × 1): $145/월
- **절감**: 월 $580 (80% 절감)

---

#### 전략 4: VPC Endpoints로 데이터 전송 비용 90% 절감

**개요**: NAT Gateway를 통한 인터넷 경유 대신 VPC Endpoint로 AWS 서비스 접근.

**적용 방법**:

```hcl
# Infrastructure 프로젝트 - network/vpc-endpoints.tf

# Gateway Endpoint (무료)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-northeast-2.s3"

  route_table_ids = concat(
    aws_route_table.private[*].id,
    [aws_route_table.public.id]
  )

  tags = merge(local.required_tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-northeast-2.dynamodb"

  route_table_ids = aws_route_table.private[*].id

  tags = merge(local.required_tags, {
    Name = "${local.name_prefix}-dynamodb-endpoint"
  })
}

# Interface Endpoint (시간당 $0.01 + 데이터 처리)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-2.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.required_tags, {
    Name = "${local.name_prefix}-ecr-api-endpoint"
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-2.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.required_tags, {
    Name = "${local.name_prefix}-ecr-dkr-endpoint"
  })
}

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-2.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(local.required_tags, {
    Name = "${local.name_prefix}-secrets-endpoint"
  })
}
```

**비용 비교** (Prod 환경 기준):
- NAT Gateway (500GB 전송): $180/월
- VPC Endpoints (Interface 3개 + 500GB 전송): $35/월
- **절감**: 월 $145 (80% 절감)

---

#### 전략 5: Reserved Instances 및 Savings Plans (30-40% 할인)

**개요**: 예측 가능한 워크로드에 대해 1년 또는 3년 약정으로 비용 절감.

**적용 대상**:
- **RDS Reserved Instances**: Shared RDS (db.t3.medium, Multi-AZ)
- **ElastiCache Reserved Nodes**: Prod Redis (cache.r6g.large)
- **Compute Savings Plans**: ECS Fargate 사용량 (시간당 일정 금액 약정)

**적용 방법**:

1. **RDS RI 구매** (AWS Console 또는 CLI):

```bash
aws rds purchase-reserved-db-instances-offering \
  --reserved-db-instances-offering-id <offering-id> \
  --reserved-db-instance-id ryuqqq-shared-rds-ri \
  --db-instance-count 1
```

2. **ElastiCache RI 구매**:

```bash
aws elasticache purchase-reserved-cache-nodes-offering \
  --reserved-cache-nodes-offering-id <offering-id> \
  --reserved-cache-node-id fileflow-prod-redis-ri \
  --cache-node-count 1
```

3. **Compute Savings Plans** (AWS Cost Explorer → Savings Plans):
   - Fargate 1년 약정: 시간당 $0.10 약정 시 30% 할인
   - 3년 약정: 시간당 $0.10 약정 시 40% 할인

**예상 절감** (1년 약정 기준):
- RDS RI: $145 → $102 (30% 할인, 월 $43 절감)
- ElastiCache RI: $120 → $84 (30% 할인, 월 $36 절감)
- Fargate Savings Plan: $132 → $92 (30% 할인, 월 $40 절감)
- **총 절감**: 월 $119 (30% 절감)

---

### 1.3 Infracost 통합

Infracost는 Terraform 코드에서 인프라 비용을 자동 계산하고 PR에 비용 변경 내역을 코멘트로 추가합니다.

#### GitHub Actions 통합

```yaml
# .github/workflows/infracost.yml
name: Infracost
on:
  pull_request:
    paths:
      - 'terraform/**'

jobs:
  infracost:
    name: Infracost Analysis
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Infracost
        uses: infracost/actions/setup@v2
        with:
          api-key: ${{ secrets.INFRACOST_API_KEY }}

      - name: Generate Infracost cost estimate baseline
        run: |
          infracost breakdown --path=terraform/fileflow \
            --format=json \
            --out-file=/tmp/infracost-base.json

      - name: Generate Infracost diff
        run: |
          infracost diff --path=terraform/fileflow \
            --format=json \
            --compare-to=/tmp/infracost-base.json \
            --out-file=/tmp/infracost.json

      - name: Post Infracost comment
        run: |
          infracost comment github \
            --path=/tmp/infracost.json \
            --repo=$GITHUB_REPOSITORY \
            --github-token=${{ secrets.GITHUB_TOKEN }} \
            --pull-request=${{ github.event.pull_request.number }} \
            --behavior=update

      - name: Check cost threshold
        run: |
          COST_DIFF=$(jq '.diffTotalMonthlyCost' /tmp/infracost.json)
          COST_PERCENT=$(jq '.percentChange' /tmp/infracost.json)

          echo "Monthly cost difference: \$${COST_DIFF}"
          echo "Percentage change: ${COST_PERCENT}%"

          # 10% 이상 증가 시 경고
          if (( $(echo "$COST_PERCENT > 10" | bc -l) )); then
            echo "::warning::Cost increase of ${COST_PERCENT}% detected"
          fi

          # 30% 이상 증가 시 실패
          if (( $(echo "$COST_PERCENT > 30" | bc -l) )); then
            echo "::error::Cost increase of ${COST_PERCENT}% exceeds 30% threshold"
            exit 1
          fi
```

#### Infracost 출력 예시

PR 코멘트에 다음과 같이 표시됩니다:

```
Monthly cost estimate

Project: terraform/fileflow

~ aws_ecs_service.app
  ~ desired_count: 2 → 4
    Monthly cost change: +$88 (+100%)

+ aws_elasticache_replication_group.redis
  + cache.r6g.large, Multi-AZ
    Monthly cost: +$120

Total monthly cost change: +$208 (+45%)

⚠️ Cost increase exceeds 10% threshold. Please review.
```

---

## 2. Rollback 절차

### 2.1 Terraform State Rollback

Terraform State를 이전 버전으로 복원하는 4가지 방법입니다.

#### 방법 1: S3 버전 복원 (권장)

**전제 조건**: S3 버킷에 버전 관리가 활성화되어 있어야 함.

```bash
# 1. 현재 State 버전 확인
aws s3api list-object-versions \
  --bucket ryuqqq-prod-tfstate \
  --prefix fileflow/terraform.tfstate \
  --query 'Versions[*].[VersionId,LastModified,IsLatest]' \
  --output table

# 2. 복원할 버전 선택 (예: 2번째 최신 버전)
VERSION_ID="<version-id-to-restore>"

# 3. 백업 생성 (현재 State를 로컬에 저장)
terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate

# 4. 이전 버전으로 복원
aws s3api copy-object \
  --bucket ryuqqq-prod-tfstate \
  --copy-source "ryuqqq-prod-tfstate/fileflow/terraform.tfstate?versionId=${VERSION_ID}" \
  --key fileflow/terraform.tfstate

# 5. State 동기화 확인
terraform refresh
terraform plan
```

---

#### 방법 2: Terraform State 직접 복원

```bash
# 1. 현재 State 백업
terraform state pull > current.tfstate

# 2. 이전 State를 로컬에서 가져오기 (Git 히스토리 또는 백업에서)
# 예: Git에서 이전 커밋의 State 가져오기
git show HEAD~1:terraform/fileflow/terraform.tfstate > previous.tfstate

# 3. 이전 State를 S3로 푸시
terraform state push previous.tfstate

# 4. Terraform plan으로 변경 내역 확인
terraform plan

# 5. 실제 인프라와 State 동기화 (필요 시)
terraform apply
```

---

#### 방법 3: 특정 리소스만 Rollback

```bash
# 1. 현재 State에서 특정 리소스 제거
terraform state rm aws_ecs_service.app

# 2. 이전 State에서 해당 리소스의 설정을 코드로 복원
# (Git 히스토리에서 ecs.tf 파일을 이전 버전으로 복원)
git checkout HEAD~1 -- terraform/fileflow/ecs.tf

# 3. Import로 실제 리소스를 State에 다시 추가
terraform import aws_ecs_service.app <cluster-name>/<service-name>

# 4. Plan으로 확인
terraform plan
```

---

#### 방법 4: 전체 State 초기화 및 Import (최후의 수단)

```bash
# 1. 현재 State 백업
terraform state pull > full-backup-$(date +%Y%m%d-%H%M%S).tfstate

# 2. State 초기화
rm -rf .terraform
terraform init

# 3. 모든 리소스를 수동으로 Import
terraform import aws_vpc.main vpc-xxxxxx
terraform import aws_subnet.private[0] subnet-xxxxxx
terraform import aws_ecs_cluster.main fileflow-prod-cluster
terraform import aws_ecs_service.app fileflow-prod-cluster/fileflow-prod-service
# ... 모든 리소스에 대해 반복

# 4. Plan으로 State와 실제 인프라의 차이 확인
terraform plan

# 5. 필요 시 Apply로 동기화
terraform apply
```

**주의**: 이 방법은 시간이 오래 걸리고 실수 가능성이 높으므로 최후의 수단으로만 사용.

---

### 2.2 Database Migration Rollback

Database 스키마 변경을 롤백하는 절차입니다.

#### 사전 준비: 자동 백업 활성화

```hcl
# Infrastructure 프로젝트 - shared/rds/main.tf
resource "aws_db_instance" "shared" {
  # ... 기타 설정

  backup_retention_period = 7  # 7일간 자동 백업 보관
  backup_window          = "03:00-04:00"  # UTC 기준 백업 시간

  # Point-in-Time Recovery 활성화 (5분마다 스냅샷)
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
}
```

---

#### Rollback 방법 1: Point-in-Time Recovery (5분 단위 복원)

```bash
# 1. 복원 가능한 시점 확인
aws rds describe-db-instances \
  --db-instance-identifier ryuqqq-shared-rds \
  --query 'DBInstances[0].[LatestRestorableTime,EarliestRestorableTime]' \
  --output table

# 2. 특정 시점으로 새 RDS 인스턴스 생성
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier ryuqqq-shared-rds \
  --target-db-instance-identifier ryuqqq-shared-rds-restored-20251022 \
  --restore-time 2025-10-22T14:30:00Z \
  --db-subnet-group-name <subnet-group-name> \
  --vpc-security-group-ids <security-group-id>

# 3. 복원된 RDS가 available 상태가 될 때까지 대기
aws rds wait db-instance-available \
  --db-instance-identifier ryuqqq-shared-rds-restored-20251022

# 4. Application에서 새 RDS Endpoint로 전환 (SSM Parameter 업데이트)
NEW_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier ryuqqq-shared-rds-restored-20251022 \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

aws ssm put-parameter \
  --name /shared/rds/prod/endpoint \
  --value "$NEW_ENDPOINT" \
  --overwrite

# 5. ECS 서비스 재배포 (새 Endpoint 반영)
aws ecs update-service \
  --cluster fileflow-prod-cluster \
  --service fileflow-prod-service \
  --force-new-deployment
```

---

#### Rollback 방법 2: 수동 스냅샷 복원

```bash
# 1. 최신 수동 스냅샷 확인
aws rds describe-db-snapshots \
  --db-instance-identifier ryuqqq-shared-rds \
  --snapshot-type manual \
  --query 'DBSnapshots[0].[DBSnapshotIdentifier,SnapshotCreateTime]' \
  --output table

# 2. 스냅샷에서 복원
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier ryuqqq-shared-rds-restored-snapshot \
  --db-snapshot-identifier rds:ryuqqq-shared-rds-2025-10-22-pre-migration \
  --db-subnet-group-name <subnet-group-name> \
  --vpc-security-group-ids <security-group-id>

# 3. Available 상태 대기 및 Endpoint 전환 (위와 동일)
```

---

#### Rollback 방법 3: Database Schema Rollback (Flyway/Liquibase)

Application 레벨에서 Schema Migration 도구를 사용하는 경우:

**Flyway 예시**:

```bash
# 1. 마이그레이션 히스토리 확인
flyway info \
  -url="jdbc:mysql://${RDS_ENDPOINT}:3306/${DB_NAME}" \
  -user="${DB_USER}" \
  -password="${DB_PASSWORD}"

# 2. 특정 버전으로 롤백 (undo 스크립트 실행)
flyway undo \
  -url="jdbc:mysql://${RDS_ENDPOINT}:3306/${DB_NAME}" \
  -user="${DB_USER}" \
  -password="${DB_PASSWORD}" \
  -target=V2.1  # V2.2를 롤백하고 V2.1로 복원

# 3. 롤백 검증
flyway validate
```

**Liquibase 예시**:

```bash
# 1. 이전 Changeset으로 롤백
liquibase rollbackCount 1 \
  --url="jdbc:mysql://${RDS_ENDPOINT}:3306/${DB_NAME}" \
  --username="${DB_USER}" \
  --password="${DB_PASSWORD}"

# 2. 특정 태그로 롤백
liquibase rollback v2.1 \
  --url="jdbc:mysql://${RDS_ENDPOINT}:3306/${DB_NAME}" \
  --username="${DB_USER}" \
  --password="${DB_PASSWORD}"
```

---

### 2.3 ECS Task Rollback

ECS 서비스를 이전 Task Definition 버전으로 롤백하는 절차입니다.

#### 방법 1: Task Definition Revision 롤백

```bash
# 1. 현재 실행 중인 Task Definition 확인
aws ecs describe-services \
  --cluster fileflow-prod-cluster \
  --services fileflow-prod-service \
  --query 'services[0].taskDefinition' \
  --output text
# 출력: arn:aws:ecs:ap-northeast-2:123456789012:task-definition/fileflow-prod:15

# 2. 이전 Task Definition Revision 목록 확인
aws ecs list-task-definitions \
  --family-prefix fileflow-prod \
  --sort DESC \
  --max-items 5
# 출력: Revision 15, 14, 13, 12, 11...

# 3. 이전 Revision (예: 14)으로 서비스 업데이트
aws ecs update-service \
  --cluster fileflow-prod-cluster \
  --service fileflow-prod-service \
  --task-definition fileflow-prod:14 \
  --force-new-deployment

# 4. 배포 상태 모니터링
aws ecs wait services-stable \
  --cluster fileflow-prod-cluster \
  --services fileflow-prod-service

# 5. 배포 완료 확인
aws ecs describe-services \
  --cluster fileflow-prod-cluster \
  --services fileflow-prod-service \
  --query 'services[0].[taskDefinition,runningCount,desiredCount]' \
  --output table
```

---

#### 방법 2: Docker Image Tag 롤백

```bash
# 1. ECR에서 사용 가능한 Image Tag 확인
aws ecr describe-images \
  --repository-name fileflow \
  --query 'sort_by(imageDetails,&imagePushedAt)[*].[imageTags[0],imagePushedAt]' \
  --output table
# 출력: latest, v1.2.3, v1.2.2, abc123def (Git SHA)

# 2. 이전 Image Tag로 Task Definition 업데이트 (Terraform)
# terraform/fileflow/ecs.tf 파일 수정
variable "image_tag" {
  default = "v1.2.2"  # 이전 버전으로 변경
}

# 3. Terraform Apply
cd terraform/fileflow
terraform apply \
  -var="image_tag=v1.2.2" \
  -var-file=environments/prod/terraform.tfvars \
  -auto-approve

# 4. 배포 완료 대기
aws ecs wait services-stable \
  --cluster fileflow-prod-cluster \
  --services fileflow-prod-service
```

---

#### 방법 3: Blue/Green Deployment Rollback (CodeDeploy 사용 시)

CodeDeploy를 사용하는 경우 자동 롤백이 가능합니다:

```hcl
# ecs.tf
resource "aws_codedeploy_deployment_group" "app" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "${local.name_prefix}-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled = true
    alarms  = [
      aws_cloudwatch_metric_alarm.ecs_5xx_errors.alarm_name,
      aws_cloudwatch_metric_alarm.ecs_response_time_high.alarm_name
    ]
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.app.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.app_https.arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }
}
```

**수동 롤백**:

```bash
# CodeDeploy 배포 중단 (자동으로 이전 버전으로 롤백)
aws deploy stop-deployment \
  --deployment-id d-XXXXXXXXX \
  --auto-rollback-enabled
```

---

### 2.4 긴급 대응 프로세스

심각한 장애 발생 시 빠른 대응을 위한 체크리스트입니다.

#### 긴급 대응 체크리스트

**1. 인시던트 선언** (P0/P1 심각도)

```bash
# Slack 알림 (자동화)
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "🚨 P0 INCIDENT: FileFlow Prod Service Down",
    "attachments": [
      {
        "color": "danger",
        "fields": [
          {"title": "Service", "value": "fileflow-prod", "short": true},
          {"title": "Severity", "value": "P0", "short": true},
          {"title": "Issue", "value": "All tasks crashed, 5xx errors 100%", "short": false}
        ]
      }
    ]
  }'
```

---

**2. 즉시 완화 조치** (Mitigation)

```bash
# Option 1: 이전 Task Definition으로 즉시 롤백
aws ecs update-service \
  --cluster fileflow-prod-cluster \
  --service fileflow-prod-service \
  --task-definition fileflow-prod:14 \
  --force-new-deployment

# Option 2: Desired Count를 0으로 설정 (서비스 중단)
aws ecs update-service \
  --cluster fileflow-prod-cluster \
  --service fileflow-prod-service \
  --desired-count 0

# Option 3: ALB에서 트래픽 차단 (503 반환)
aws elbv2 modify-listener \
  --listener-arn <listener-arn> \
  --default-actions Type=fixed-response,FixedResponseConfig={StatusCode=503}
```

---

**3. 근본 원인 분석** (Root Cause Analysis)

```bash
# CloudWatch Logs 확인 (최근 1시간 에러)
aws logs filter-log-events \
  --log-group-name /ecs/fileflow-prod/application \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --filter-pattern "ERROR" \
  --query 'events[*].message' \
  --output text

# X-Ray Traces 확인
aws xray get-trace-summaries \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --filter-expression 'http.status = 5xx'

# ECS Task 로그 확인 (최근 실패한 Task)
TASK_ARN=$(aws ecs list-tasks \
  --cluster fileflow-prod-cluster \
  --service-name fileflow-prod-service \
  --desired-status STOPPED \
  --query 'taskArns[0]' \
  --output text)

aws ecs describe-tasks \
  --cluster fileflow-prod-cluster \
  --tasks $TASK_ARN \
  --query 'tasks[0].stoppedReason'
```

---

**4. 복구 및 검증**

```bash
# 롤백 완료 후 서비스 상태 확인
aws ecs describe-services \
  --cluster fileflow-prod-cluster \
  --services fileflow-prod-service \
  --query 'services[0].[runningCount,desiredCount]'

# Health Check 통과 확인
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names fileflow-prod-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

curl -s http://$ALB_DNS/actuator/health | jq .

# CloudWatch Alarms 상태 확인 (모두 OK 여야 함)
aws cloudwatch describe-alarms \
  --alarm-name-prefix fileflow-prod \
  --state-value ALARM \
  --query 'MetricAlarms[*].[AlarmName,StateValue]' \
  --output table
```

---

**5. Postmortem 작성**

인시던트 종료 후 48시간 이내 Postmortem 작성:

```markdown
# Postmortem: FileFlow Prod 서비스 중단 (2025-10-22)

## 요약
- **일시**: 2025-10-22 14:30 ~ 15:15 (45분)
- **심각도**: P0
- **영향 범위**: FileFlow Prod 서비스 전체 중단, 사용자 100% 영향
- **근본 원인**: ECS Task Definition의 환경변수 오타로 인한 Database 연결 실패

## 타임라인
- 14:30: 배포 시작 (v1.2.3 → v1.2.4)
- 14:32: CloudWatch Alarm 발생 (Task Count Zero)
- 14:35: On-call 엔지니어 알림 수신
- 14:40: 인시던트 선언 (P0)
- 14:45: 이전 버전으로 롤백 시작 (v1.2.3)
- 15:10: 서비스 복구 완료
- 15:15: 모든 알람 정상 (OK)

## 근본 원인
Task Definition의 `DB_HOST` 환경변수가 `rds.endpoint` 대신 `rds.endpint`로 오타 입력됨.

## 개선 사항
1. **단기**: Pre-deployment validation script에 환경변수 검증 로직 추가
2. **중기**: Terraform variables validation 강화 (정규식 패턴 검증)
3. **장기**: Blue/Green 배포 도입으로 자동 롤백 기능 구현
```

---

## 3. 다중 리전 전략 (DR)

### 3.1 DR 아키텍처 개요

**Primary Region**: `ap-northeast-2` (서울)
**DR Region**: `ap-northeast-1` (도쿄)

#### 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│                      Route53 (Global DNS)                    │
│  Weighted Routing Policy: Primary 100% / DR 0% (Failover)   │
└───────────────┬─────────────────────┬───────────────────────┘
                │                     │
    ┌───────────▼──────────┐  ┌──────▼────────────────┐
    │  Primary Region      │  │  DR Region            │
    │  ap-northeast-2      │  │  ap-northeast-1       │
    ├──────────────────────┤  ├───────────────────────┤
    │ - ECS Fargate        │  │ - ECS Fargate (OFF)   │
    │ - ALB (Active)       │  │ - ALB (Standby)       │
    │ - RDS (Master)       │━━│ - RDS (Read Replica)  │
    │ - ElastiCache        │  │ - ElastiCache (OFF)   │
    │ - S3 (Primary)       │━━│ - S3 (Replica)        │
    │ - CloudWatch         │  │ - CloudWatch          │
    └──────────────────────┘  └───────────────────────┘
                ━━: Cross-Region Replication
```

---

### 3.2 RTO/RPO 목표

| 리소스 | RPO | RTO | 복구 방법 |
|--------|-----|-----|-----------|
| **Application (ECS)** | 0분 (Stateless) | 15분 | Task 재배포 |
| **Database (RDS)** | 15분 (Replica lag) | 30분 | Read Replica 승격 |
| **Cache (Redis)** | 데이터 손실 허용 | 10분 | 새 클러스터 생성 |
| **Object Storage (S3)** | 15분 (CRR) | 즉시 | Route53 전환 |
| **Logs** | 5분 (Kinesis Firehose) | 즉시 | 다중 리전 스트리밍 |

**전체 RTO**: **2시간 이내**
**전체 RPO**: **15분 이내** (RDS Read Replica 동기화 지연 기준)

---

### 3.3 DR 환경 구축

#### Step 1: DR Region VPC 생성

```hcl
# Infrastructure 프로젝트 - network/dr-region.tf

provider "aws" {
  alias  = "dr"
  region = "ap-northeast-1"
}

module "vpc_dr" {
  source = "../../modules/vpc"
  providers = {
    aws = aws.dr
  }

  name_prefix = "ryuqqq-dr"
  cidr_block  = "10.1.0.0/16"

  availability_zones = ["ap-northeast-1a", "ap-northeast-1c"]

  public_subnets  = ["10.1.0.0/20", "10.1.16.0/20"]
  private_subnets = ["10.1.32.0/19", "10.1.64.0/19"]
  data_subnets    = ["10.1.96.0/20", "10.1.112.0/20"]

  enable_nat_gateway   = true
  single_nat_gateway   = true  # DR은 비용 절감을 위해 Single NAT
  enable_dns_hostnames = true

  tags = local.required_tags
}

# VPC Peering (Primary ↔ DR)
resource "aws_vpc_peering_connection" "primary_to_dr" {
  vpc_id      = module.vpc_primary.vpc_id
  peer_vpc_id = module.vpc_dr.vpc_id
  peer_region = "ap-northeast-1"
  auto_accept = false

  tags = merge(local.required_tags, {
    Name = "primary-to-dr-peering"
  })
}

resource "aws_vpc_peering_connection_accepter" "dr" {
  provider                  = aws.dr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_dr.id
  auto_accept               = true

  tags = merge(local.required_tags, {
    Name = "dr-accept-primary-peering"
  })
}

# Route Table Updates (Primary → DR)
resource "aws_route" "primary_to_dr" {
  for_each = toset(module.vpc_primary.private_route_table_ids)

  route_table_id            = each.value
  destination_cidr_block    = module.vpc_dr.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_dr.id
}

# Route Table Updates (DR → Primary)
resource "aws_route" "dr_to_primary" {
  provider = aws.dr
  for_each = toset(module.vpc_dr.private_route_table_ids)

  route_table_id            = each.value
  destination_cidr_block    = module.vpc_primary.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_dr.id
}
```

---

#### Step 2: RDS Read Replica 생성 (Cross-Region)

```hcl
# Infrastructure 프로젝트 - shared/rds/dr-replica.tf

provider "aws" {
  alias  = "dr"
  region = "ap-northeast-1"
}

# DR Region KMS Key (RDS 암호화용)
resource "aws_kms_key" "rds_dr" {
  provider                = aws.dr
  description             = "KMS key for RDS in DR region"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(local.required_tags, {
    Name = "ryuqqq-dr-rds-key"
  })
}

# Cross-Region Read Replica
resource "aws_db_instance" "shared_replica" {
  provider               = aws.dr
  identifier             = "ryuqqq-shared-rds-replica"
  replicate_source_db    = aws_db_instance.shared.arn
  instance_class         = "db.t3.medium"
  publicly_accessible    = false
  skip_final_snapshot    = false
  final_snapshot_identifier = "ryuqqq-shared-rds-replica-final-snapshot"

  # DR Region은 Multi-AZ 불필요 (비용 절감)
  multi_az = false

  # DR Region KMS Key로 암호화
  kms_key_id = aws_kms_key.rds_dr.arn

  backup_retention_period = 7

  performance_insights_enabled = true
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = merge(local.required_tags, {
    Name        = "ryuqqq-shared-rds-dr-replica"
    Environment = "dr"
  })
}

# SSM Parameters (DR Region Endpoint)
resource "aws_ssm_parameter" "rds_dr_endpoint" {
  provider = aws.dr
  name     = "/shared/rds/dr/endpoint"
  type     = "String"
  value    = aws_db_instance.shared_replica.endpoint

  tags = local.required_tags
}
```

**Read Replica 승격 스크립트** (Failover 시 실행):

```bash
#!/bin/bash
# promote-rds-replica.sh

DR_INSTANCE_ID="ryuqqq-shared-rds-replica"
DR_REGION="ap-northeast-1"

echo "===== RDS Read Replica Promotion ====="

# 1. Read Replica를 독립 실행형 DB로 승격
aws rds promote-read-replica \
  --db-instance-identifier $DR_INSTANCE_ID \
  --region $DR_REGION \
  --backup-retention-period 7

# 2. Available 상태 대기 (승격 완료까지 5-10분 소요)
echo "Waiting for promotion to complete..."
aws rds wait db-instance-available \
  --db-instance-identifier $DR_INSTANCE_ID \
  --region $DR_REGION

# 3. Multi-AZ 활성화 (Prod 환경은 고가용성 필요)
aws rds modify-db-instance \
  --db-instance-identifier $DR_INSTANCE_ID \
  --region $DR_REGION \
  --multi-az \
  --apply-immediately

echo "✅ RDS Replica promoted successfully"
echo "New Master Endpoint: $(aws rds describe-db-instances \
  --db-instance-identifier $DR_INSTANCE_ID \
  --region $DR_REGION \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)"
```

---

#### Step 3: S3 Cross-Region Replication

```hcl
# Infrastructure 프로젝트 - shared/s3/dr-replication.tf

# DR Region S3 Bucket
resource "aws_s3_bucket" "logs_dr" {
  provider = aws.dr
  bucket   = "ryuqqq-dr-logs"

  tags = merge(local.required_tags, {
    Name        = "ryuqqq-dr-logs"
    Environment = "dr"
  })
}

resource "aws_s3_bucket_versioning" "logs_dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.logs_dr.id

  versioning_configuration {
    status = "Enabled"
  }
}

# DR Region KMS Key (S3 암호화용)
resource "aws_kms_key" "s3_dr" {
  provider                = aws.dr
  description             = "KMS key for S3 in DR region"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(local.required_tags, {
    Name = "ryuqqq-dr-s3-key"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.logs_dr.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_dr.arn
    }
    bucket_key_enabled = true
  }
}

# Primary Bucket에 Replication 설정
resource "aws_s3_bucket_replication_configuration" "logs" {
  depends_on = [aws_s3_bucket_versioning.logs]
  bucket     = aws_s3_bucket.logs.id
  role       = aws_iam_role.s3_replication.arn

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"

    filter {
      prefix = ""  # 모든 객체 복제
    }

    destination {
      bucket        = aws_s3_bucket.logs_dr.arn
      storage_class = "STANDARD_IA"  # DR은 비용 절감을 위해 IA 사용

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.s3_dr.arn
      }

      # 15분 이내 복제 (RPO 목표)
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

    delete_marker_replication {
      status = "Enabled"
    }
  }
}

# IAM Role for Replication
resource "aws_iam_role" "s3_replication" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_replication" {
  role = aws_iam_role.s3_replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.logs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl"
        ]
        Resource = "${aws_s3_bucket.logs.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = "${aws_s3_bucket.logs_dr.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.s3.arn
        Condition = {
          StringLike = {
            "kms:ViaService" = "s3.ap-northeast-2.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt"
        ]
        Resource = aws_kms_key.s3_dr.arn
        Condition = {
          StringLike = {
            "kms:ViaService" = "s3.ap-northeast-1.amazonaws.com"
          }
        }
      }
    ]
  })
}
```

---

#### Step 4: Route53 Failover Routing

```hcl
# Infrastructure 프로젝트 - network/route53-failover.tf

# Primary Region Health Check
resource "aws_route53_health_check" "primary" {
  fqdn              = aws_lb.primary.dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/actuator/health"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(local.required_tags, {
    Name = "fileflow-primary-health-check"
  })
}

# DR Region Health Check
resource "aws_route53_health_check" "dr" {
  fqdn              = aws_lb.dr.dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/actuator/health"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(local.required_tags, {
    Name = "fileflow-dr-health-check"
  })
}

# Hosted Zone
data "aws_route53_zone" "main" {
  name = "ryuqqq.com"
}

# Primary Record (Failover Primary)
resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "fileflow.ryuqqq.com"
  type    = "A"

  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = aws_lb.primary.dns_name
    zone_id                = aws_lb.primary.zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.primary.id
}

# DR Record (Failover Secondary)
resource "aws_route53_record" "dr" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "fileflow.ryuqqq.com"
  type    = "A"

  set_identifier = "dr"
  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = aws_lb.dr.dns_name
    zone_id                = aws_lb.dr.zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.dr.id
}
```

---

#### Step 5: CloudFront with Origin Failover (선택 사항)

CloudFront를 사용하면 자동 Failover와 캐싱으로 성능 향상 가능:

```hcl
# Infrastructure 프로젝트 - network/cloudfront.tf

# Origin Group (Primary + DR)
resource "aws_cloudfront_origin_group" "fileflow" {
  origin_id = "fileflow-origin-group"

  failover_criteria {
    status_codes = [403, 404, 500, 502, 503, 504]
  }

  member {
    origin_id = "primary"
  }

  member {
    origin_id = "dr"
  }
}

resource "aws_cloudfront_distribution" "fileflow" {
  enabled = true
  comment = "FileFlow with automatic failover"

  origin {
    origin_id   = "primary"
    domain_name = aws_lb.primary.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    origin_id   = "dr"
    domain_name = aws_lb.dr.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin_group {
    origin_id = aws_cloudfront_origin_group.fileflow.origin_id

    member {
      origin_id = "primary"
    }

    member {
      origin_id = "dr"
    }
  }

  default_cache_behavior {
    target_origin_id       = aws_cloudfront_origin_group.fileflow.origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 3600
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.fileflow.arn
    ssl_support_method  = "sni-only"
  }

  tags = merge(local.required_tags, {
    Name = "fileflow-cloudfront"
  })
}
```

---

### 3.4 Failover 시나리오

#### 시나리오 1: Primary Region 전체 장애

**자동 Failover** (Route53 Health Check 기반):

1. **Health Check 실패** (3회 연속, 90초 소요)
   - Route53가 Primary ALB health endpoint를 체크
   - 3회 실패 시 Primary를 unhealthy로 표시

2. **DNS Failover** (자동, 60초 소요)
   - Route53가 자동으로 DR Record로 트래픽 전환
   - TTL(60초) 후 모든 클라이언트가 DR로 연결

3. **Application 활성화** (수동, 5-10분 소요)

```bash
#!/bin/bash
# failover-to-dr.sh

DR_REGION="ap-northeast-1"
DR_CLUSTER="fileflow-dr-cluster"
DR_SERVICE="fileflow-dr-service"

echo "===== Starting DR Failover ====="

# 1. RDS Read Replica 승격
./promote-rds-replica.sh

# 2. ECS 서비스 활성화 (Desired Count 증가)
aws ecs update-service \
  --cluster $DR_CLUSTER \
  --service $DR_SERVICE \
  --desired-count 4 \
  --region $DR_REGION

# 3. ElastiCache Redis 생성
aws elasticache create-replication-group \
  --replication-group-id fileflow-dr-redis \
  --replication-group-description "DR Redis for FileFlow" \
  --engine redis \
  --cache-node-type cache.r6g.large \
  --num-cache-clusters 2 \
  --automatic-failover-enabled \
  --region $DR_REGION

# 4. Health Check 통과 대기
echo "Waiting for DR service to become healthy..."
while true; do
  HEALTH=$(curl -s https://fileflow.ryuqqq.com/actuator/health | jq -r '.status')
  if [ "$HEALTH" == "UP" ]; then
    echo "✅ DR service is healthy"
    break
  fi
  sleep 10
done

echo "===== DR Failover Complete ====="
```

**예상 총 RTO**: **15-20분** (Health Check 90초 + DNS 60초 + Application 10분)

---

#### 시나리오 2: Primary Region 복구 (Failback)

Primary Region이 복구되면 원래대로 전환:

```bash
#!/bin/bash
# failback-to-primary.sh

PRIMARY_REGION="ap-northeast-2"
DR_REGION="ap-northeast-1"

echo "===== Starting Failback to Primary ====="

# 1. Primary RDS 복구 (DR에서 Primary로 데이터 복제)
# 옵션 A: DR RDS를 Primary로 승격 (권장)
# 옵션 B: Primary RDS 재생성 후 DR에서 복원

# 2. Primary ECS 서비스 활성화
aws ecs update-service \
  --cluster fileflow-prod-cluster \
  --service fileflow-prod-service \
  --desired-count 4 \
  --region $PRIMARY_REGION

# 3. Primary Health Check 통과 대기
echo "Waiting for Primary service to become healthy..."
while true; do
  PRIMARY_HEALTH=$(aws route53 get-health-check-status \
    --health-check-id <primary-health-check-id> \
    --query 'HealthCheckObservations[0].StatusReport.Status' \
    --output text)

  if [ "$PRIMARY_HEALTH" == "Success" ]; then
    echo "✅ Primary service is healthy"
    break
  fi
  sleep 30
done

# 4. Route53 자동 전환 (Health Check 성공 시 자동)
echo "Route53 will automatically switch to Primary within 60 seconds"

# 5. DR 서비스 비활성화 (비용 절감)
echo "Scaling down DR service..."
aws ecs update-service \
  --cluster fileflow-dr-cluster \
  --service fileflow-dr-service \
  --desired-count 0 \
  --region $DR_REGION

# 6. DR RDS를 Read Replica로 다시 생성
echo "Recreating DR Read Replica..."
aws rds create-db-instance-read-replica \
  --db-instance-identifier ryuqqq-shared-rds-replica \
  --source-db-instance-identifier <primary-rds-arn> \
  --region $DR_REGION

echo "===== Failback Complete ====="
```

---

## 4. 검증 및 모니터링

### 4.1 비용 검증

```bash
# Infracost로 현재 비용 확인
cd terraform/fileflow
infracost breakdown --path . --format table

# 월간 비용 트렌드 확인 (AWS Cost Explorer)
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.BlendedCost.Amount]' \
  --output table
```

---

### 4.2 Rollback 절차 검증

**정기 Rollback 훈련** (분기마다 1회):

```bash
# 1. Staging 환경에서 Rollback 시뮬레이션
cd terraform/fileflow
terraform apply -var="environment=staging" -var="image_tag=v1.2.3"

# 2. 의도적으로 실패 시나리오 생성 (잘못된 image tag)
terraform apply -var="environment=staging" -var="image_tag=invalid"

# 3. Rollback 실행
./scripts/rollback-ecs.sh staging v1.2.3

# 4. 복구 시간 측정
echo "Rollback completed in: $(( $(date +%s) - $START_TIME )) seconds"
```

---

### 4.3 DR 환경 검증

**월간 DR Drill** (매월 첫째 주 수요일):

```bash
# 1. DR Region으로 수동 Failover
./scripts/failover-to-dr.sh

# 2. DR 환경에서 기능 테스트
curl -X POST https://fileflow.ryuqqq.com/api/test \
  -H "Content-Type: application/json" \
  -d '{"test": "dr-validation"}'

# 3. RTO/RPO 측정
echo "RTO: Failover completed in XX minutes"
echo "RPO: Data loss was YY minutes (Replica lag)"

# 4. Primary로 Failback
./scripts/failback-to-primary.sh

# 5. Postmortem 작성 (개선 사항 기록)
```

---

### 4.4 지속적 모니터링

**CloudWatch Dashboard** (비용 및 DR 상태):

```hcl
# monitoring/cloudwatch-dashboard.tf
resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "fileflow-operations-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average", label = "Primary CPU" }],
            ["...", { region = "ap-northeast-1", label = "DR CPU" }]
          ]
          period = 300
          stat   = "Average"
          region = "ap-northeast-2"
          title  = "ECS CPU Utilization (Primary vs DR)"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "ReplicaLag", { DBInstanceIdentifier = "ryuqqq-shared-rds-replica" }]
          ]
          period = 60
          stat   = "Average"
          region = "ap-northeast-1"
          title  = "RDS Replica Lag (RPO Metric)"
          yAxis = {
            left = {
              min = 0
              max = 900  # 15분 = 900초
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Route53", "HealthCheckStatus", { HealthCheckId = "<primary-health-check-id>" }],
            ["...", { HealthCheckId = "<dr-health-check-id>" }]
          ]
          period = 60
          stat   = "Average"
          title  = "Route53 Health Check Status"
        }
      }
    ]
  })
}
```

---

## 다음 단계

✅ **Part 7 완료!** 이제 마지막 문서인 **[Part 8: 트러블슈팅 가이드](hybrid-08-troubleshooting-guide.md)**로 이동하세요.

Part 8에서는 다음 내용을 다룹니다:
- 일반적인 문제 및 해결 방법
- 모범 사례
- FAQ (자주 묻는 질문)

---

## 참고 자료

### 관련 문서
- [하이브리드 인프라 가이드 메인](hybrid-infrastructure-guide.md)
- [Part 5: 배포 가이드](hybrid-05-deployment-guide.md)
- [Part 6: 모니터링 가이드](hybrid-06-monitoring-guide.md)
- [Runbooks - ECS High CPU](../runbooks/ecs-high-cpu.md)
- [Runbooks - ECS Task Count Zero](../runbooks/ecs-task-count-zero.md)

### AWS 문서
- [AWS Well-Architected Framework - Cost Optimization](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html)
- [ECS Fargate Spot](https://docs.aws.amazon.com/AmazonECS/latest/userguide/fargate-capacity-providers.html)
- [RDS Read Replicas](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html)
- [S3 Cross-Region Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)
- [Route53 Health Checks and Failover](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html)

### 도구
- [Infracost](https://www.infracost.io/docs/)
- [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)

---

**Last Updated**: 2025-10-22
**Version**: 1.0
