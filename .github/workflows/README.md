# GitHub Actions Reusable Workflows

Infrastructure 레포에서 제공하는 재사용 가능한 워크플로우입니다.

## 📋 제공 워크플로우

| 워크플로우 | 용도 | 파일 |
|------------|------|------|
| **Docker Build & Push** | Java/Gradle 빌드 → Docker 이미지 → ECR 푸시 | `reusable-build-docker.yml` |
| **ECS Deploy** | Task Definition 업데이트 → ECS 서비스 배포 | `reusable-deploy-ecs.yml` |

---

## 🐳 reusable-build-docker.yml

### 기능
- Java/Gradle 프로젝트 JAR 빌드
- Docker 이미지 빌드
- Amazon ECR 푸시
- 이미지 태그 자동 생성
- 취약점 스캔 (선택)

### 사용법

```yaml
jobs:
  build:
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-build-docker.yml@main
    with:
      ecr-repository: my-project-web-api-prod
      component: web-api
      dockerfile: bootstrap/bootstrap-web-api/Dockerfile
      gradle-task: ":bootstrap:bootstrap-web-api:bootJar"
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

### 입력 파라미터

| 파라미터 | 필수 | 기본값 | 설명 |
|----------|------|--------|------|
| `ecr-repository` | ✅ | - | ECR 레포지토리 이름 |
| `component` | ✅ | - | 컴포넌트명 (이미지 태그에 사용) |
| `dockerfile` | ✅ | - | Dockerfile 경로 |
| `gradle-task` | ✅ | - | Gradle 빌드 태스크 |
| `java-version` | | `21` | Java 버전 |
| `aws-region` | | `ap-northeast-2` | AWS 리전 |
| `timeout-minutes` | | `30` | 빌드 타임아웃 |
| `run-tests` | | `false` | 테스트 실행 여부 |
| `build-args` | | - | Docker build arguments |
| `build-context` | | `.` | Docker build context |

### 출력 값

| 출력 | 설명 |
|------|------|
| `image-uri` | 푸시된 이미지 전체 URI |
| `image-tag` | 이미지 태그 |
| `ecr-repository` | ECR 레포지토리 이름 |

---

## 🚀 reusable-deploy-ecs.yml

### 기능
- 현재 Task Definition 조회
- 이미지 URI 업데이트
- 새 Task Definition 등록
- ECS 서비스 업데이트
- 서비스 안정화 대기

### 사용법

```yaml
jobs:
  deploy:
    needs: build
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-deploy-ecs.yml@main
    with:
      ecs-cluster: my-cluster-prod
      ecs-service: my-service-prod
      image-uri: ${{ needs.build.outputs.image-uri }}
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

### 입력 파라미터

| 파라미터 | 필수 | 기본값 | 설명 |
|----------|------|--------|------|
| `ecs-cluster` | ✅ | - | ECS 클러스터 이름 |
| `ecs-service` | ✅ | - | ECS 서비스 이름 |
| `image-uri` | ✅ | - | 배포할 Docker 이미지 URI |
| `container-name` | | (첫 번째) | 업데이트할 컨테이너 이름 |
| `aws-region` | | `ap-northeast-2` | AWS 리전 |
| `timeout-minutes` | | `20` | 배포 타임아웃 |
| `wait-for-stability` | | `true` | 안정화 대기 여부 |
| `force-new-deployment` | | `true` | 강제 새 배포 |

### 출력 값

| 출력 | 설명 |
|------|------|
| `task-definition-arn` | 새 Task Definition ARN |
| `deployment-id` | ECS 배포 ID |

---

## 📁 예시 워크플로우

`examples/` 폴더에서 프로젝트별 예시를 확인하세요:

- `crawlinghub-build-deploy.yml.example` - CrawlingHub (전체 빌드)
- `fileflow-build-deploy.yml.example` - FileFlow (변경 감지 빌드)

---

## 🏷️ 네이밍 컨벤션

### 리소스 네이밍 규칙

```
{project}-{component}-{env}

예시:
- ECR: crawlinghub-web-api-prod
- ECS Cluster: crawlinghub-prod
- ECS Service: crawlinghub-web-api-prod
```

### 이미지 태그 규칙

```
{component}-{run_number}-{short_sha}

예시: web-api-123-abc1234
```

---

## ⚙️ 사전 요구사항

### 1. GitHub Secrets 설정

각 프로젝트 레포에 다음 Secret이 필요합니다:

| Secret | 설명 | 조회 방법 |
|--------|------|----------|
| `AWS_ROLE_ARN` | GitHub Actions IAM Role ARN | `aws ssm get-parameter --name "/github-actions/role-arn" --query "Parameter.Value" --output text` |

### 2. IAM Role 허용 목록

Infrastructure 레포의 `terraform/environments/prod/bootstrap/variables.tf`에서
`allowed_github_repos`에 프로젝트가 등록되어 있어야 합니다.

### 3. ECR 레포지토리

Terraform으로 미리 생성되어 있어야 합니다.

---

## 🔄 마이그레이션 가이드

기존 워크플로우에서 전환하는 방법:

### Before (기존)
```yaml
# 450줄의 반복적인 코드
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  ...
- name: Login to ECR
  ...
- name: Build Docker image
  ...
- name: Push to ECR
  ...
```

### After (Reusable Workflow)
```yaml
# 10줄로 단순화
build:
  uses: ryu-qqq/Infrastructure/.github/workflows/reusable-build-docker.yml@main
  with:
    ecr-repository: my-project-prod
    component: web-api
    dockerfile: bootstrap/bootstrap-web-api/Dockerfile
    gradle-task: ":bootstrap:bootstrap-web-api:bootJar"
  secrets:
    AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

---

## 🐛 트러블슈팅

### ECR 레포지토리를 찾을 수 없음
```
Error: Repository not found
```
→ ECR 레포지토리가 Terraform으로 생성되어 있는지 확인

### IAM Role Assume 실패
```
Error: Could not assume role
```
→ `allowed_github_repos`에 프로젝트가 등록되어 있는지 확인

### ECS 서비스를 찾을 수 없음
```
Error: Service not found
```
→ `ecs-cluster`와 `ecs-service` 이름이 정확한지 확인

---

## 📚 관련 문서

- [GitHub Actions IAM Role 관리](../../README.md#github-actions-iam-role-관리)
- [Terraform 모듈 카탈로그](../../terraform/modules/README.md)
