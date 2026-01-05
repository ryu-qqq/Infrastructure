# GitHub Actions Reusable Workflows

Infrastructure 프로젝트의 GitHub Actions 워크플로우를 다른 레포에서 재사용하는 방법입니다.

## Reusable Workflow 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    ryu-qqq/Infrastructure                    │
│                     (Central Repository)                     │
├─────────────────────────────────────────────────────────────┤
│  .github/workflows/                                          │
│  ├── reusable-sync-jira.yml      ← Jira 동기화              │
│  ├── reusable-build-docker.yml   ← Docker 빌드              │
│  ├── reusable-deploy-ecs.yml     ← ECS 배포                 │
│  └── reusable-notify-slack.yml   ← Slack 알림               │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   AuthHub       │ │   CrawlingHub   │ │   FileFlow      │
│   (Consumer)    │ │   (Consumer)    │ │   (Consumer)    │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

---

## 1. Jira 동기화 (reusable-sync-jira.yml)

### 기능
- GitHub Issue 생성 시 Jira 티켓 자동 생성
- Issue 상태 변경 시 Jira 동기화
- 양방향 링크 연결

### 사용법

```yaml
# .github/workflows/sync-jira.yml
name: Sync to Jira

on:
  issues:
    types: [opened, edited, closed, reopened, labeled]
  issue_comment:
    types: [created]

jobs:
  sync:
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-sync-jira.yml@main
    with:
      jira-project-key: IN          # Jira 프로젝트 키
      issue-type: Task              # 기본 이슈 타입
      sync-comments: true           # 코멘트 동기화 여부
    secrets:
      JIRA_BASE_URL: ${{ secrets.JIRA_BASE_URL }}
      JIRA_USER_EMAIL: ${{ secrets.JIRA_USER_EMAIL }}
      JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
```

### 입력 파라미터

| 파라미터 | 필수 | 기본값 | 설명 |
|---------|------|--------|------|
| `jira-project-key` | ✅ | - | Jira 프로젝트 키 (예: IN, AUTH) |
| `issue-type` | ❌ | Task | 생성할 Jira 이슈 타입 |
| `sync-comments` | ❌ | true | 코멘트 동기화 여부 |
| `sync-labels` | ❌ | true | 라벨 동기화 여부 |
| `auto-close` | ❌ | true | Issue 종료 시 Jira도 종료 |

### 필요한 Secrets

| Secret | 설명 | 예시 |
|--------|------|------|
| `JIRA_BASE_URL` | Jira 인스턴스 URL | https://yourorg.atlassian.net |
| `JIRA_USER_EMAIL` | Jira 계정 이메일 | user@example.com |
| `JIRA_API_TOKEN` | Jira API 토큰 | xxxxxxxxxxx |

---

## 2. Docker 빌드 (reusable-build-docker.yml)

### 기능
- Docker 이미지 빌드
- ECR 푸시
- 이미지 태깅 (git SHA, latest, timestamp)
- 보안 스캔

### 사용법

```yaml
# .github/workflows/deploy.yml
jobs:
  build:
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-build-docker.yml@main
    with:
      ecr-repository: my-app
      dockerfile-path: ./Dockerfile
      build-context: .
      aws-region: ap-northeast-2
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### 입력 파라미터

| 파라미터 | 필수 | 기본값 | 설명 |
|---------|------|--------|------|
| `ecr-repository` | ✅ | - | ECR 레포지토리 이름 |
| `dockerfile-path` | ❌ | ./Dockerfile | Dockerfile 경로 |
| `build-context` | ❌ | . | Docker 빌드 컨텍스트 |
| `aws-region` | ❌ | ap-northeast-2 | AWS 리전 |
| `enable-scan` | ❌ | true | 보안 스캔 활성화 |

### 출력값

| 출력 | 설명 |
|-----|------|
| `image-uri` | 빌드된 이미지 전체 URI |
| `image-tag` | 이미지 태그 (git SHA) |

---

## 3. ECS 배포 (reusable-deploy-ecs.yml)

### 기능
- ECS 태스크 정의 업데이트
- 서비스 배포
- 롤링 업데이트
- 헬스체크

### 사용법

```yaml
jobs:
  deploy:
    needs: build
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-deploy-ecs.yml@main
    with:
      cluster-name: my-cluster
      service-name: my-service
      task-definition: my-task-def
      container-name: app
      image-uri: ${{ needs.build.outputs.image-uri }}
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

---

## 4. Slack 알림 (reusable-notify-slack.yml)

### 기능
- 배포 결과 Slack 알림
- Block Kit 사용
- 컴포넌트별 상태 표시
- 실패 시 멘션

### 사용법

```yaml
jobs:
  notify:
    needs: [build, deploy]
    if: always()
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-notify-slack.yml@main
    with:
      project-name: MyApp
      environment: prod
      status: ${{ needs.deploy.result.txt }}
      components: |
        [
          {"name": "api", "status": "${{ needs.build.result }}", "image": "${{ needs.build.outputs.image-tag }}"}
        ]
    secrets:
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## 전체 파이프라인 예시

```yaml
# .github/workflows/deploy.yml
name: Build and Deploy

on:
  push:
    branches: [main]

jobs:
  # 1. Docker 빌드
  build:
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-build-docker.yml@main
    with:
      ecr-repository: my-app
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

  # 2. ECS 배포
  deploy:
    needs: build
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-deploy-ecs.yml@main
    with:
      cluster-name: prod-cluster
      service-name: my-app
      image-uri: ${{ needs.build.outputs.image-uri }}
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

  # 3. Slack 알림
  notify:
    needs: [build, deploy]
    if: always()
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-notify-slack.yml@main
    with:
      project-name: MyApp
      environment: prod
      status: ${{ needs.deploy.result.txt }}
      components: '[{"name":"api","status":"${{ needs.build.result.txt }}"}]'
    secrets:
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## Secrets 설정 가이드

### Organization Secrets (권장)

여러 레포에서 공통으로 사용하는 시크릿은 Organization 레벨에서 설정:

```
GitHub Organization Settings
 → Secrets and variables
   → Actions
     → New organization secret
```

| Secret | 공유 범위 |
|--------|----------|
| `JIRA_BASE_URL` | All repositories |
| `JIRA_USER_EMAIL` | All repositories |
| `JIRA_API_TOKEN` | All repositories |
| `AWS_ACCESS_KEY_ID` | Selected repositories |
| `AWS_SECRET_ACCESS_KEY` | Selected repositories |

### Repository Secrets

레포별로 다른 값이 필요한 경우:

```
Repository Settings
 → Secrets and variables
   → Actions
     → New repository secret
```

---

## 트러블슈팅

### 권한 오류

Reusable workflow 호출 시 권한이 필요한 경우:

```yaml
jobs:
  sync:
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-sync-jira.yml@main
    permissions:
      issues: write
      contents: read
```

### Workflow 버전 고정

안정성을 위해 특정 버전/커밋 사용:

```yaml
# 브랜치 사용 (최신)
uses: ryu-qqq/Infrastructure/.github/workflows/reusable-sync-jira.yml@main

# 태그 사용 (안정)
uses: ryu-qqq/Infrastructure/.github/workflows/reusable-sync-jira.yml@v1.0.0

# 커밋 SHA 사용 (고정)
uses: ryu-qqq/Infrastructure/.github/workflows/reusable-sync-jira.yml@abc123
```
