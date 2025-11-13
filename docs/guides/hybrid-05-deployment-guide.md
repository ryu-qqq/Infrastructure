# 하이브리드 Terraform 인프라: 배포 가이드

**작성일**: 2025-10-22
**버전**: 1.0
**대상 독자**: 배포 담당자, DevOps 엔지니어
**소요 시간**: 30분
**선행 문서**: [Application 프로젝트 설정](hybrid-04-application-setup.md)

---

## 📋 목차

1. [개요](#개요)
2. [Terraform 검증](#terraform-검증)
3. [배포 전 체크리스트](#배포-전-체크리스트)
4. [배포 실행](#배포-실행)
5. [배포 후 검증](#배포-후-검증)
6. [CI/CD 통합](#cicd-통합)
7. [Atlantis 통합](#atlantis-통합-옵션)
8. [PR 자동화 전략](#pr-자동화-전략)
9. [트러블슈팅](#트러블슈팅)
10. [다음 단계](#다음-단계)

---

## 개요

이 가이드는 **하이브리드 인프라 구조의 배포 프로세스**를 다룹니다. Terraform 검증부터 CI/CD 통합까지 전체 배포 워크플로를 설명합니다.

### 배포 프로세스 개요

```
1. Terraform 검증
   ↓
2. 배포 전 체크리스트
   ↓
3. 환경별 배포 실행 (Dev → Staging → Prod)
   ↓
4. 배포 후 검증
   ↓
5. CI/CD 파이프라인 설정
```

### 배포 순서

1. **Infrastructure 프로젝트 배포** (플랫폼 팀)
   - Network → KMS → Shared RDS → ECR
   - SSM Parameters 자동 생성

2. **Application 프로젝트 배포** (서비스 팀)
   - Dev → Staging → Prod 순차 배포
   - 환경별 검증 필수

---

## Terraform 검증

### 1. 초기화

```bash
cd {service-name}/infrastructure/terraform

# Backend 초기화
terraform init

# 출력 확인
# - Terraform 버전
# - Provider 버전
# - Backend 설정
```

**기대 결과**:
```
Terraform has been successfully initialized!
```

### 2. 형식 확인

```bash
# 모든 .tf 파일 형식 확인
terraform fmt -recursive

# 변경된 파일 확인
git diff
```

**기대 결과**: 모든 파일이 표준 형식을 따름

### 3. 구문 검증

```bash
# Terraform 구문 검증
terraform validate
```

**기대 결과**:
```
Success! The configuration is valid.
```

### 4. Plan 확인 (환경별)

#### Dev 환경

```bash
terraform plan -var-file=environments/dev/terraform.tfvars
```

**검토 사항**:
- 생성될 리소스 개수 확인
- 예상치 못한 변경 사항 확인
- Security Group, IAM 정책 검토

#### Staging 환경

```bash
terraform plan -var-file=environments/staging/terraform.tfvars
```

#### Prod 환경

```bash
terraform plan -var-file=environments/prod/terraform.tfvars
```

**⚠️ 주의**: Prod 환경은 반드시 수동 검토 필요

---

## 배포 전 체크리스트

### Infrastructure 프로젝트 확인

- [ ] **Network 모듈 배포 완료**
  ```bash
  cd /path/to/infrastructure/terraform/network
  terraform output
  ```
  - VPC ID 확인
  - Subnet IDs 확인 (Public, Private, Data)

- [ ] **KMS 모듈 배포 완료**
  ```bash
  cd /path/to/infrastructure/terraform/kms
  terraform output
  ```
  - 7개 KMS Key ARN 확인

- [ ] **Shared RDS 배포 완료** (사용 시)
  ```bash
  cd /path/to/infrastructure/terraform/rds
  terraform output
  ```
  - RDS Endpoint 확인
  - Security Group ID 확인

- [ ] **ECR Repository 배포 완료**
  ```bash
  cd /path/to/infrastructure/terraform/ecr/{service-name}
  terraform output
  ```
  - ECR Repository URL 확인

### SSM Parameters 확인

```bash
# 모든 SSM Parameters 확인
aws ssm get-parameters-by-path \
  --path /shared \
  --recursive \
  --region ap-northeast-2 \
  --query 'Parameters[*].[Name]' \
  --output table

# 기대 결과: 최소 13개 이상의 Parameters
# - /shared/network/* (4개)
# - /shared/kms/* (7개)
# - /shared/ecr/* (1개)
# - /shared/rds/* (3개, 옵션)
```

**특정 Parameter 확인**:
```bash
aws ssm get-parameter --name /shared/network/vpc-id --region ap-northeast-2
aws ssm get-parameter --name /shared/kms/s3-key-arn --region ap-northeast-2
```

### Application Terraform 파일 준비

- [ ] **`data.tf`**: 모든 필요한 SSM Parameter 데이터 소스 추가
- [ ] **`locals.tf`**: 모든 SSM Parameter 값 참조
- [ ] **`database.tf`**: Shared RDS 연결 (사용 시)
- [ ] **모든 리소스**: 올바른 KMS key 사용
- [ ] **`iam.tf`**: Remote state 제거, 로컬 변수 사용
- [ ] **환경별 `terraform.tfvars`**: 작성 완료

### Terraform 검증

- [ ] `terraform init` 성공
- [ ] `terraform validate` 통과
- [ ] `terraform plan` 검토 완료 (예상 리소스 생성 확인)

### 보안 검증

```bash
# tfsec 스캔
tfsec .

# checkov 스캔
checkov -d .

# KMS 암호화 확인
grep -r "kms_key" *.tf
```

**확인 사항**:
- [ ] 모든 KMS 암호화 활성화
- [ ] Secrets Manager 사용 (하드코딩 없음)
- [ ] Security Group 최소 권한
- [ ] IAM 역할 최소 권한

---

## 배포 실행

### 환경별 배포 순서

**권장 배포 순서**: Dev → Staging → Prod

### 1. Dev 환경 배포

```bash
cd {service-name}/infrastructure/terraform

# Plan 최종 확인
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply 실행
terraform apply -var-file=environments/dev/terraform.tfvars
```

**배포 시간**: 약 5-10분

**생성 리소스**:
- ECS Cluster, Service, Task Definition
- ALB + Target Group + Listener
- Security Groups
- ElastiCache Redis
- S3 Buckets
- SQS Queues
- IAM Roles and Policies
- CloudWatch Log Groups
- Database + User (Shared RDS 사용 시)

### 2. Staging 환경 배포

```bash
# Dev 환경 검증 후 진행
terraform apply -var-file=environments/staging/terraform.tfvars
```

**배포 시간**: 약 10-15분

### 3. Prod 환경 배포

**⚠️ 주의**: 프로덕션 배포는 승인 필요

```bash
# 배포 전 최종 검토
terraform plan -var-file=environments/prod/terraform.tfvars

# 승인 후 배포
terraform apply -var-file=environments/prod/terraform.tfvars
```

**배포 시간**: 약 15-20분 (Multi-AZ 구성)

**Prod 환경 특징**:
- Multi-AZ 활성화 (RDS, Redis, ECS)
- 더 높은 리소스 사양
- 자동 백업 활성화
- Performance Insights 활성화

---

## 배포 후 검증

### 1. ECS 서비스 상태 확인

```bash
# ECS 서비스 상태
aws ecs describe-services \
  --cluster ${SERVICE_NAME}-${ENV}-cluster \
  --services ${SERVICE_NAME}-${ENV}-service \
  --region ap-northeast-2 \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
  --output table
```

**기대 결과**:
```
Status: ACTIVE
Running: 2
Desired: 2
```

### 2. Task 상태 확인

```bash
# Running Tasks 확인
aws ecs list-tasks \
  --cluster ${SERVICE_NAME}-${ENV}-cluster \
  --service-name ${SERVICE_NAME}-${ENV}-service \
  --region ap-northeast-2

# Task 상세 정보
aws ecs describe-tasks \
  --cluster ${SERVICE_NAME}-${ENV}-cluster \
  --tasks <task-arn> \
  --region ap-northeast-2
```

**확인 사항**:
- Task가 RUNNING 상태
- Health Check 통과
- Container 정상 실행

### 3. RDS 연결 확인

#### ECS Exec 사용

```bash
# ECS Exec 활성화 확인
aws ecs describe-services \
  --cluster ${SERVICE_NAME}-${ENV}-cluster \
  --services ${SERVICE_NAME}-${ENV}-service \
  --query 'services[0].enableExecuteCommand' \
  --region ap-northeast-2

# Container 접속
aws ecs execute-command \
  --cluster ${SERVICE_NAME}-${ENV}-cluster \
  --task <task-id> \
  --container ${SERVICE_NAME} \
  --command "/bin/sh" \
  --interactive
```

#### MySQL 연결 테스트

```bash
# Container 내부에서 실행
# 1. Secrets Manager에서 DB 자격 증명 가져오기
aws secretsmanager get-secret-value \
  --secret-id ${SERVICE_NAME}-${ENV}-db-credentials \
  --query SecretString \
  --output text | jq .

# 2. MySQL 연결
mysql -h <rds-endpoint> -u ${DB_USERNAME} -p${DB_PASSWORD} ${DB_NAME}

# 3. 기본 쿼리 테스트
mysql> SHOW DATABASES;
mysql> USE ${DB_NAME};
mysql> SHOW TABLES;
```

### 4. Redis 연결 확인

```bash
# Redis Endpoint 확인
aws elasticache describe-replication-groups \
  --replication-group-id ${SERVICE_NAME}-${ENV}-redis \
  --region ap-northeast-2 \
  --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint' \
  --output table

# Container 내부에서 Redis 연결
redis-cli -h <redis-endpoint> -a <auth-token> ping

# 기대 결과: PONG
```

### 5. ALB Health Check 확인

```bash
# ALB DNS Name 확인
aws elbv2 describe-load-balancers \
  --names ${SERVICE_NAME}-${ENV}-alb \
  --region ap-northeast-2 \
  --query 'LoadBalancers[0].DNSName' \
  --output text

# Health Check 테스트
curl http://<alb-dns-name>/actuator/health

# 기대 결과: {"status":"UP"}
```

### 6. CloudWatch Logs 확인

```bash
# 최근 로그 확인
aws logs tail \
  /ecs/${SERVICE_NAME}-${ENV}/application \
  --follow \
  --region ap-northeast-2

# 특정 시간 범위 로그
aws logs filter-log-events \
  --log-group-name /ecs/${SERVICE_NAME}-${ENV}/application \
  --start-time $(date -u -d '5 minutes ago' +%s)000 \
  --region ap-northeast-2
```

### 7. 통합 검증 스크립트

```bash
#!/bin/bash
# validate-deployment.sh

SERVICE_NAME="fileflow"
ENV="dev"
REGION="ap-northeast-2"

echo "===== Deployment Validation for $SERVICE_NAME-$ENV ====="

# 1. ECS Service
echo "1. Checking ECS Service..."
aws ecs describe-services \
  --cluster ${SERVICE_NAME}-${ENV}-cluster \
  --services ${SERVICE_NAME}-${ENV}-service \
  --region $REGION \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# 2. ALB Health
echo "2. Checking ALB Health..."
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names ${SERVICE_NAME}-${ENV}-alb \
  --region $REGION \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

curl -s http://$ALB_DNS/actuator/health | jq .

# 3. Redis Status
echo "3. Checking Redis..."
aws elasticache describe-replication-groups \
  --replication-group-id ${SERVICE_NAME}-${ENV}-redis \
  --region $REGION \
  --query 'ReplicationGroups[0].Status'

# 4. S3 Bucket
echo "4. Checking S3 Bucket..."
aws s3 ls s3://${SERVICE_NAME}-${ENV}-storage --region $REGION

# 5. SQS Queue
echo "5. Checking SQS Queue..."
aws sqs get-queue-attributes \
  --queue-url $(aws sqs get-queue-url --queue-name ${SERVICE_NAME}-${ENV}-file-processing --region $REGION --query QueueUrl --output text) \
  --attribute-names ApproximateNumberOfMessages \
  --region $REGION

echo "===== Validation Complete ====="
```

---

## CI/CD 통합

### GitHub Actions 워크플로

#### Infrastructure 프로젝트 워크플로

**파일**: `/path/to/infrastructure/.github/workflows/terraform-plan.yml`

```yaml
name: Terraform Plan (Infrastructure)

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
    name: Terraform Plan - ${{ matrix.module }}
    runs-on: ubuntu-latest
    timeout-minutes: 10

    strategy:
      matrix:
        module:
          - network
          - kms
          - rds
          - ecr/fileflow

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
```

**파일**: `/path/to/infrastructure/.github/workflows/terraform-apply.yml`

```yaml
name: Terraform Apply (Infrastructure)

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
    name: Terraform Apply - ${{ github.event.inputs.module || 'network' }}
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

**파일**: `/path/to/{service-name}/.github/workflows/terraform-plan.yml`

```yaml
name: Terraform Plan (Application)

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

**파일**: `/path/to/{service-name}/.github/workflows/deploy.yml`

```yaml
name: Deploy Application

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
          ECR_REPOSITORY: ${{ vars.SERVICE_NAME }}
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
        env:
          SERVICE_NAME: ${{ vars.SERVICE_NAME }}
          ENV: ${{ github.event.inputs.environment || 'dev' }}
        run: |
          aws ecs update-service \
            --cluster ${SERVICE_NAME}-${ENV}-cluster \
            --service ${SERVICE_NAME}-${ENV}-service \
            --force-new-deployment \
            --region ap-northeast-2
```

---

## Atlantis 통합 (옵션)

Atlantis를 사용하여 PR 기반 Terraform 워크플로를 자동화할 수 있습니다.

### Atlantis 설정 파일

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

  # Application 프로젝트 (FileFlow 예시)
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

  - name: fileflow-staging
    dir: infrastructure/terraform
    workspace: staging
    terraform_version: v1.9.0
    autoplan:
      when_modified:
        - "*.tf"
        - "environments/staging/*.tfvars"
    apply_requirements:
      - approved
      - mergeable

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

### Atlantis 사용 방법

```bash
# PR에서 Plan 실행
atlantis plan -p fileflow-dev

# Apply 실행 (승인 후)
atlantis apply -p fileflow-dev

# 특정 디렉토리 Plan
atlantis plan -d infrastructure/terraform
```

---

## PR 자동화 전략

### 1. PR 생성 시 자동 실행

**자동 실행 항목**:
- ✅ Terraform fmt check
- ✅ Terraform validate
- ✅ Terraform plan (환경별)
- ✅ Security scan (tfsec, checkov)
- ✅ Cost analysis (Infracost)

### 2. PR 승인 및 Merge 시

**자동 실행 항목**:
- ✅ Terraform apply (Infrastructure 프로젝트)
- ✅ Docker image build & push (Application 프로젝트)
- ✅ ECS service update (Application 프로젝트)

### 3. 배포 승인 프로세스

#### 환경별 승인 전략

| 환경 | 승인 필요 | 승인자 | 배포 시간 | 자동 Rollback |
|------|----------|--------|----------|--------------|
| **Dev** | ❌ 자동 | - | PR Merge 즉시 | ✅ |
| **Staging** | ✅ 필요 | Platform Team | 영업시간 내 | ✅ |
| **Prod** | ✅ 필요 | Platform Lead + CTO | 화/목 오전 10시 | ✅ |

#### GitHub Environment 설정

```yaml
# .github/workflows/deploy.yml
environment: production
  approval_required: true
  reviewers:
    - platform-team
    - cto
  wait_timer: 0  # 승인 후 즉시 배포
```

### 4. 자동 Rollback 조건

**Rollback 트리거**:
- ECS Health Check 실패 (5분 연속)
- 5xx 에러율 > 1%
- 메모리 사용률 > 90%
- Task 실행 실패 3회 이상

**Rollback 프로세스**:
```bash
# 이전 Task Definition으로 Rollback
aws ecs update-service \
  --cluster ${SERVICE_NAME}-${ENV}-cluster \
  --service ${SERVICE_NAME}-${ENV}-service \
  --task-definition ${SERVICE_NAME}-${ENV}:${PREVIOUS_REVISION} \
  --force-new-deployment
```

---

## 트러블슈팅

### 문제 1: Terraform Apply 실패

**증상**:
```
Error: error creating ECS Service: InvalidParameterException
```

**원인**: Subnet이나 Security Group이 존재하지 않음

**해결**:
```bash
# SSM Parameters 확인
aws ssm get-parameters-by-path --path /shared --recursive

# VPC와 Subnets 확인
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"
```

### 문제 2: ECS Task가 시작되지 않음

**증상**: Task가 PENDING 상태에서 멈춤

**원인**: ECR Image Pull 권한 없음 또는 Image가 없음

**해결**:
```bash
# ECR Repository 확인
aws ecr describe-repositories --repository-names ${SERVICE_NAME}

# Image가 있는지 확인
aws ecr list-images --repository-name ${SERVICE_NAME}

# IAM 역할 권한 확인
aws iam get-role-policy --role-name ${SERVICE_NAME}-ecs-execution-role --policy-name ecr-access
```

### 문제 3: Health Check 실패

**증상**: ALB Health Check가 계속 실패

**원인**: Container가 Health Check 엔드포인트를 제공하지 않음

**해결**:
```bash
# Task 로그 확인
aws logs tail /ecs/${SERVICE_NAME}-${ENV}/application --follow

# Container 접속하여 직접 확인
aws ecs execute-command \
  --cluster ${SERVICE_NAME}-${ENV}-cluster \
  --task <task-id> \
  --container ${SERVICE_NAME} \
  --command "/bin/sh" \
  --interactive

# Health Check 엔드포인트 테스트
curl localhost:8080/actuator/health
```

---

## 다음 단계

✅ **배포 가이드 완료**

**다음 가이드**: [모니터링 가이드 (hybrid-06-monitoring-guide.md)](hybrid-06-monitoring-guide.md)

**다음 단계 내용**:
1. CloudWatch Logs 통합
2. X-Ray 트레이싱 설정
3. Application Insights 설정
4. 메트릭 및 알람 설정 (CPU, Memory, 5xx, RDS)
5. 로그 집계 및 분석 (S3 Export)
6. 중앙 집중식 모니터링 (AMP + AMG)

---

## 참고 자료

### 관련 문서
- [개요 및 시작하기](hybrid-01-overview.md)
- [아키텍처 설계](hybrid-02-architecture-design.md)
- [Infrastructure 프로젝트 설정](hybrid-03-infrastructure-setup.md)
- [Application 프로젝트 설정](hybrid-04-application-setup.md)
- [모니터링 가이드](hybrid-06-monitoring-guide.md)

### GitHub Actions 문서
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Actions](https://github.com/aws-actions)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)

### Atlantis 문서
- [Atlantis Documentation](https://www.runatlantis.io/docs/)
- [Atlantis 서버 운영 가이드](../atlantis-operations-guide.md)

---

**Last Updated**: 2025-10-22
**버전**: 1.0
