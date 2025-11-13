# Multi-Repo Infrastructure Strategy

## 📋 Overview

이 프로젝트는 **Multi-Repository 아키텍처**를 사용하여 공유 인프라와 애플리케이션별 인프라를 분리 관리합니다.

## 🏗️ Repository Structure

### Infrastructure Repository (이 레포)
**역할**: 공유 인프라 관리
**소유**: Platform Team

```
infrastructure/
├── terraform/
│   ├── network/           # VPC, Subnets, Routing
│   ├── kms/               # Encryption Keys
│   ├── rds/               # Shared Database
│   ├── ecr/               # Container Registries (모든 서비스)
│   │   ├── fileflow/
│   │   ├── api-server/
│   │   └── crawler/
│   ├── secrets/           # Secrets Manager
│   ├── logging/           # CloudWatch Logs
│   └── monitoring/        # CloudWatch, Prometheus
├── atlantis.yaml          # Atlantis configuration
└── atlantis-file-flow.yaml  # Template for FileFlow repo
```

### Application Repositories (별도 레포)
**역할**: 애플리케이션 코드 + 앱별 인프라
**소유**: 각 서비스 팀

```
fileflow/
├── src/                   # Application code
├── terraform/
│   ├── ecs-service/       # ECS Cluster, Service, Task Definition
│   ├── redis/             # ElastiCache Redis
│   ├── s3/                # S3 Buckets
│   └── alb/               # Application Load Balancer
├── atlantis.yaml          # Copied from infrastructure/atlantis-file-flow.yaml
└── .github/workflows/
    └── deploy.yml         # Build → Push to ECR → Update ECS
```

## 🔄 Resource Ownership

| 리소스 | 관리 레포 | 이유 |
|--------|----------|------|
| VPC, Subnets | infrastructure | 모든 서비스가 공유 |
| KMS Keys | infrastructure | 암호화 정책 중앙 관리 |
| RDS | infrastructure | 여러 서비스가 공유 |
| **ECR** | **infrastructure** | 컨테이너 레지스트리는 공유 리소스 |
| ECS Cluster/Service | application | 서비스별 독립 배포 |
| ElastiCache | application | 서비스 전용 캐시 |
| S3 Buckets | application | 서비스 전용 스토리지 |
| ALB | application | 서비스 전용 로드밸런서 |

## 🚀 Deployment Workflows

### 1. 공유 인프라 변경 (Infrastructure Repo)

```bash
# 1. Infrastructure 레포에서 작업
cd infrastructure
git checkout -b feat/add-kms-key

# 2. Terraform 변경
vim terraform/kms/main.tf

# 3. PR 생성
git add .
git commit -m "feat: Add KMS key for new service"
git push origin feat/add-kms-key

# 4. Atlantis가 자동으로 plan 실행
# PR 코멘트: atlantis plan -p kms-prod

# 5. 승인 후 apply
# PR 코멘트: atlantis apply -p kms-prod

# 6. 머지
```

### 2. 애플리케이션 인프라 변경 (FileFlow Repo)

```bash
# 1. FileFlow 레포에서 작업
cd fileflow
git checkout -b feat/increase-ecs-cpu

# 2. Terraform 변경
vim terraform/ecs-service/main.tf

# 3. PR 생성
git add .
git commit -m "feat: Increase ECS task CPU to 1024"
git push origin feat/increase-ecs-cpu

# 4. Atlantis가 자동으로 plan 실행
# PR 코멘트: atlantis plan -p fileflow-ecs-prod

# 5. 승인 후 apply
# PR 코멘트: atlantis apply -p fileflow-ecs-prod

# 6. 머지
```

### 3. 애플리케이션 코드 배포 (FileFlow Repo)

```bash
# 1. 코드 변경
cd fileflow
git checkout -b feat/new-feature
vim src/app.py

# 2. PR 생성
git add .
git commit -m "feat: Add new feature"
git push origin feat/new-feature

# 3. GitHub Actions 자동 실행
# - Docker 이미지 빌드
# - Infrastructure 레포의 ECR에 푸시
# - ECS 서비스 업데이트 (새 이미지 배포)

# 4. 머지
```

## 🔗 Cross-Repository References

애플리케이션 레포에서 Infrastructure 레포의 리소스를 참조하는 방법:

### ECR Repository 참조

```hcl
# fileflow/terraform/ecs-service/data.tf
data "aws_ecr_repository" "fileflow" {
  name = "fileflow"  # Infrastructure 레포에서 생성
}

# main.tf
resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([{
    name  = "fileflow"
    image = "${data.aws_ecr_repository.fileflow.repository_url}:${var.image_tag}"
  }])
}
```

### RDS 접속 정보 참조

```hcl
# fileflow/terraform/ecs-service/data.tf
data "aws_ssm_parameter" "rds_endpoint" {
  name = "/infrastructure/rds/prod-shared-mysql/endpoint"
}

data "aws_ssm_parameter" "rds_password" {
  name = "/infrastructure/rds/prod-shared-mysql/password"
}

# main.tf
resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([{
    environment = [
      {
        name  = "DB_HOST"
        value = data.aws_ssm_parameter.rds_endpoint.value
      }
    ]
    secrets = [
      {
        name      = "DB_PASSWORD"
        valueFrom = data.aws_ssm_parameter.rds_password.arn
      }
    ]
  }])
}
```

### VPC/Subnet 참조

```hcl
# fileflow/terraform/ecs-service/data.tf
data "aws_ssm_parameter" "vpc_id" {
  name = "/infrastructure/network/vpc-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/infrastructure/network/private-subnet-ids"
}

# main.tf
resource "aws_ecs_service" "app" {
  network_configuration {
    subnets = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  }
}
```

## 🤖 Atlantis Configuration

### Infrastructure Repo Atlantis Setup

**한 번만 설정**: GitHub App이 infrastructure 레포를 감시

```yaml
# infrastructure/atlantis.yaml
projects:
  - name: network-prod
    dir: terraform/network
  - name: kms-prod
    dir: terraform/kms
  - name: ecr-prod
    dir: terraform/ecr/fileflow
```

### Application Repo Atlantis Setup

**각 앱 레포마다 설정**: GitHub App이 각 레포를 감시

```bash
# 1. Infrastructure 레포에서 템플릿 복사
cp infrastructure/atlantis-file-flow.yaml fileflow/atlantis.yaml

# 2. 프로젝트명 수정
vim fileflow/atlantis.yaml

# 3. Git 커밋
cd fileflow
git add atlantis.yaml
git commit -m "chore: Add Atlantis configuration"
git push

# 4. GitHub App에 레포 추가
# GitHub → Settings → GitHub Apps → Atlantis
# → Repository access → Add: ryuqqq/fileflow
```

## 📚 Benefits of Multi-Repo

### ✅ Advantages

1. **권한 분리**: 팀별로 레포 접근 권한 관리
2. **독립 배포**: 서비스별 독립적인 배포 주기
3. **코드 격리**: 애플리케이션 코드와 인프라 코드 분리
4. **작은 레포 크기**: 각 레포가 작고 빠름
5. **팀 자율성**: 서비스 팀이 자체 인프라 관리

### ⚠️ Considerations

1. **의존성 관리**: SSM Parameter Store로 리소스 공유
2. **복잡도 증가**: 여러 레포 관리 필요
3. **Atlantis 설정**: 각 레포마다 atlantis.yaml 필요
4. **일관성 유지**: 공유 리소스 변경 시 영향 범위 확인

## 🔧 Best Practices

### 1. Shared Resources in Infrastructure Repo

공유 리소스는 항상 Infrastructure 레포에서 관리:
- VPC, Subnets
- KMS Keys
- RDS (shared database)
- **ECR (container registry)**
- Secrets Manager (공유 시크릿)
- CloudWatch Logs (중앙 로깅)

### 2. Application-Specific Resources in App Repo

서비스 전용 리소스는 애플리케이션 레포에서 관리:
- ECS Cluster, Service, Task Definition
- ElastiCache (서비스 전용)
- S3 Buckets (서비스 전용)
- ALB (서비스 전용)

### 3. Use SSM Parameter Store for Cross-Repo References

```hcl
# Infrastructure 레포에서 Output을 SSM에 저장
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/infrastructure/network/vpc-id"
  type  = "String"
  value = aws_vpc.main.id
}

# Application 레포에서 SSM에서 읽기
data "aws_ssm_parameter" "vpc_id" {
  name = "/infrastructure/network/vpc-id"
}
```

### 4. Version Control for atlantis.yaml Templates

```bash
# 템플릿 업데이트 시
cd infrastructure
vim atlantis-file-flow.yaml
git commit -m "docs: Update Atlantis template for FileFlow"

# 각 앱 레포에 반영
cd ../fileflow
cp ../infrastructure/atlantis-file-flow.yaml atlantis.yaml
git commit -m "chore: Update Atlantis configuration from template"
```

## 🆕 Adding New Application Repository

```bash
# 1. Infrastructure 레포에서 ECR 추가
cd infrastructure/terraform/ecr
mkdir -p new-service
vim new-service/main.tf  # ECR 리소스 정의

# 2. Atlantis 설정 업데이트
vim infrastructure/atlantis.yaml
# - name: ecr-new-service-prod
#   dir: terraform/ecr/new-service

# 3. 새 앱 레포 생성
git clone https://github.com/ryuqqq/new-service.git
cd new-service

# 4. Atlantis 설정 복사 및 수정
cp ../infrastructure/atlantis-file-flow.yaml atlantis.yaml
sed -i 's/fileflow/new-service/g' atlantis.yaml

# 5. Terraform 디렉토리 구성
mkdir -p terraform/{ecs-service,redis,s3}

# 6. GitHub App에 레포 추가
# GitHub → Settings → GitHub Apps → Atlantis → Add repository
```

## 📞 Support

- Infrastructure 관련: Platform Team
- Application 인프라: 각 서비스 팀
- Atlantis 문제: Platform Team

## 🔗 Related Documentation

- [Infrastructure Repository](../../README.md)
- [Atlantis Operations Guide](../guides/atlantis-operations-guide.md)
- [Hybrid Infrastructure Guide](../guides/hybrid-infrastructure-guide.md)
