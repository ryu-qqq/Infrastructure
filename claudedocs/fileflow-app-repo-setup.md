# FileFlow 애플리케이션 레포지토리 설정 가이드

## 개요

이 문서는 FileFlow 애플리케이션 레포지토리의 권장 구조와 필요한 GitHub Actions 워크플로우를 설명합니다.

## 하이브리드 인프라 관리 구조

### Infrastructure 레포 (중앙 관리)
- **역할**: 공유 인프라 및 ECS 서비스 인프라 관리
- **관리 대상**:
  - VPC, 서브넷, 라우팅 테이블
  - RDS, Secrets Manager, KMS
  - ECS 클러스터, 서비스, 태스크 정의
  - ALB, 타겟 그룹, 리스너 룰
  - ECR 레포지토리
- **자동화**: Atlantis + GitHub Actions

### FileFlow 애플리케이션 레포 (앱 관리)
- **역할**: 애플리케이션 코드 및 배포 관리
- **관리 대상**:
  - 애플리케이션 소스 코드
  - Docker 이미지 빌드
  - ECS 서비스 배포 (태스크 정의 업데이트)
- **자동화**: GitHub Actions만

## FileFlow 앱 레포 디렉토리 구조

```
fileflow/
├── .github/
│   └── workflows/
│       ├── ci.yml                    # 빌드 및 테스트
│       ├── build-and-push.yml        # ECR 푸시
│       └── deploy.yml                # ECS 배포
├── app/                              # 애플리케이션 소스
│   ├── src/
│   ├── tests/
│   └── requirements.txt
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── scripts/
│   └── deploy-ecs.sh                 # ECS 배포 스크립트
└── README.md
```

**주의**: `atlantis.yaml` 파일 없음 (Atlantis 비활성화)

## 필요한 GitHub Actions 워크플로우

### 1. CI 워크플로우 (ci.yml)

```yaml
name: CI

on:
  pull_request:
    branches: [main, develop]
    paths:
      - 'app/**'
      - 'docker/**'
      - '.github/workflows/ci.yml'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install -r app/requirements.txt
          pip install -r app/requirements-dev.txt

      - name: Run unit tests
        run: pytest app/tests/unit

      - name: Run integration tests
        run: pytest app/tests/integration

      - name: Code coverage
        run: pytest --cov=app --cov-report=xml
```

### 2. Build and Push 워크플로우 (build-and-push.yml)

```yaml
name: Build and Push

on:
  push:
    branches: [main]
    paths:
      - 'app/**'
      - 'docker/**'
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

env:
  AWS_REGION: ap-northeast-2
  ECR_REPOSITORY: fileflow

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.meta.outputs.git_sha }}

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Generate Image Tags
        id: meta
        run: |
          GIT_SHA=$(git rev-parse --short HEAD)
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          REGISTRY=${{ steps.login-ecr.outputs.registry }}

          TAGS="${REGISTRY}/${{ env.ECR_REPOSITORY }}:${GIT_SHA}"
          TAGS="${TAGS},${REGISTRY}/${{ env.ECR_REPOSITORY }}:latest"
          TAGS="${TAGS},${REGISTRY}/${{ env.ECR_REPOSITORY }}:${TIMESTAMP}"

          echo "tags=${TAGS}" >> $GITHUB_OUTPUT
          echo "git_sha=${GIT_SHA}" >> $GITHUB_OUTPUT

      - name: Build and Push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./docker/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Scan Image
        run: |
          sleep 30
          aws ecr describe-image-scan-findings \
            --repository-name ${{ env.ECR_REPOSITORY }} \
            --image-id imageTag=${{ steps.meta.outputs.git_sha }} \
            --region ${{ env.AWS_REGION }}
```

### 3. Deploy 워크플로우 (deploy.yml)

```yaml
name: Deploy to ECS

on:
  workflow_run:
    workflows: ["Build and Push"]
    types: [completed]
    branches: [main]
  workflow_dispatch:
    inputs:
      image_tag:
        description: 'Image tag to deploy'
        required: true
        type: string

permissions:
  id-token: write
  contents: read

env:
  AWS_REGION: ap-northeast-2
  ECS_CLUSTER: prod-cluster
  ECS_SERVICE: fileflow
  CONTAINER_NAME: fileflow

jobs:
  deploy:
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'workflow_dispatch' }}

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Get Image Tag
        id: image
        run: |
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            IMAGE_TAG="${{ inputs.image_tag }}"
          else
            IMAGE_TAG=$(git rev-parse --short HEAD)
          fi
          echo "tag=${IMAGE_TAG}" >> $GITHUB_OUTPUT

      - name: Download Task Definition
        run: |
          aws ecs describe-task-definition \
            --task-definition fileflow \
            --query taskDefinition \
            > task-definition.json

      - name: Update Task Definition
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: task-definition.json
          container-name: ${{ env.CONTAINER_NAME }}
          image: ${{ secrets.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ steps.image.outputs.tag }}

      - name: Deploy to ECS
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true

      - name: Deployment Summary
        run: |
          echo "✅ Deployment Complete!"
          echo "🏷️  Image Tag: ${{ steps.image.outputs.tag }}"
          echo "🔗 ECS Service: ${{ env.ECS_CLUSTER }}/${{ env.ECS_SERVICE }}"
```

## 불필요한 것들 (Infrastructure 레포에서만 사용)

### ❌ 전체 Governance Validators
- `check-tags.sh` - 공유 인프라에만 적용
- `check-encryption.sh` - KMS 키는 Infrastructure 레포에서 관리
- `check-naming.sh` - 전체 리소스 네이밍은 중앙 관리

### ❌ 전체 Security Scans
- tfsec/checkov 전체 스캔 - Infrastructure 레포에서 실행
- 애플리케이션 레포는 **Docker 이미지 스캔만** 필요

### ❌ Atlantis 설정
- `atlantis.yaml` 파일 없음
- Atlantis는 Infrastructure 레포에만 적용

### ❌ Terraform 인프라 관리
- ECS 서비스, ALB, IAM 역할 등은 Infrastructure 레포에서 관리
- 애플리케이션 레포는 **배포만** 담당

## 최소한의 검증 (권장)

애플리케이션 레포에 Terraform 코드가 있다면 (예: 환경변수, 시크릿 참조):

```yaml
# .github/workflows/validate-tf.yml (간소화 버전)
name: Terraform Validation

on:
  pull_request:
    paths:
      - 'terraform/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        working-directory: terraform
        run: terraform init -backend=false

      - name: Terraform Validate
        working-directory: terraform
        run: terraform validate
```

## 배포 플로우

### 1. 애플리케이션 코드 변경
```
개발자 → PR 생성 → CI 워크플로우 실행 → 테스트 통과 → 머지
```

### 2. Docker 이미지 빌드 및 푸시
```
main 브랜치 머지 → Build and Push 워크플로우 → ECR 푸시 → 이미지 스캔
```

### 3. ECS 배포
```
Build 완료 → Deploy 워크플로우 → 태스크 정의 업데이트 → ECS 서비스 업데이트 → 헬스 체크
```

### 4. 인프라 변경 (드물게 발생)
```
Infrastructure 레포 → terraform/fileflow/ 수정 → PR 생성 → Atlantis plan → 승인 → Atlantis apply
```

## Atlantis vs GitHub Actions 역할 구분

| 작업 | Infrastructure 레포 | FileFlow 앱 레포 |
|------|---------------------|------------------|
| VPC, 서브넷, RDS | Atlantis + GitHub Actions | - |
| ECS 클러스터, 서비스 정의 | Atlantis + GitHub Actions | - |
| ECR 레포지토리 | Atlantis + GitHub Actions | - |
| 애플리케이션 빌드 | - | GitHub Actions |
| Docker 이미지 푸시 | - | GitHub Actions |
| ECS 배포 (태스크 정의 업데이트) | - | GitHub Actions |
| Governance 검증 | GitHub Actions | - |
| 보안 스캔 (인프라) | GitHub Actions | - |
| 보안 스캘 (이미지) | - | GitHub Actions |

## 필요한 GitHub Secrets (FileFlow 앱 레포)

```yaml
# AWS 인증
AWS_ROLE_ARN: arn:aws:iam::123456789012:role/GitHubActions-FileFlow-Deploy

# ECR
ECR_REGISTRY: 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com

# 선택 사항
SLACK_WEBHOOK_URL: https://hooks.slack.com/services/...
```

## 권장 IAM 역할 정책 (FileFlow 배포용)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImageScanFindings"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeServices"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole"
    }
  ]
}
```

## 참고 문서

- [Infrastructure 레포 CLAUDE.md](/Users/sangwon-ryu/infrastructure/CLAUDE.md)
- [Atlantis 설정](/Users/sangwon-ryu/infrastructure/atlantis.yaml)
- [GitHub Actions 워크플로우 예시](/Users/sangwon-ryu/infrastructure/.github/workflows/)
- [ECS 배포 가이드](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-types.html)
