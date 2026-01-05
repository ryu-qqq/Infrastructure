# Workflow Automation Guide

이 문서는 Infrastructure 프로젝트의 자동화 워크플로우를 다른 레포지토리에서 재사용하기 위한 가이드입니다.

## 개요

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Event 발생                             │
│            (Issue 생성, PR 생성, PR Review 등)                   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
          ┌───────────────┴───────────────┐
          │                               │
          ▼                               ▼
┌─────────────────────┐       ┌─────────────────────┐
│  GitHub Actions     │       │   n8n Workflows     │
│  (Reusable)         │       │   (Webhook 기반)    │
├─────────────────────┤       ├─────────────────────┤
│ • Jira 동기화       │       │ • AI 코드 리뷰      │
│ • Terraform 검증    │       │ • 승인/거절 처리    │
│ • Docker 빌드       │       │ • Slack 알림        │
│ • ECS 배포          │       │ • 코드 자동 수정    │
└─────────────────────┘       └─────────────────────┘
```

## 워크플로우 유형

### GitHub Actions (Reusable Workflows)

| 워크플로우 | 파일명 | 설명 |
|-----------|--------|------|
| Jira 동기화 | `reusable-sync-jira.yml` | Issue를 Jira에 동기화 |
| Docker 빌드 | `reusable-build-docker.yml` | Docker 이미지 빌드 및 ECR 푸시 |
| ECS 배포 | `reusable-deploy-ecs.yml` | ECS 서비스 배포 |
| Slack 알림 | `reusable-notify-slack.yml` | 배포 결과 Slack 알림 |
| Infra 검증 | `infra-checks.yml` | Terraform 검증 (tfsec, checkov) |

### n8n Workflows

| 워크플로우 | 파일명 | 설명 |
|-----------|--------|------|
| Issue 오케스트레이터 | `infra-issue-orchestrator.json` | Issue 처리 및 AI 코드 생성 |

## 문서 목록

- [GitHub Actions Reusable 가이드](./github-actions.md)
- [n8n 워크플로우 범용화 가이드](./n8n-workflows.md)
- [다른 레포 적용 가이드](./multi-repo-guide.md)

## 빠른 시작

### 1. 다른 레포에서 Jira 동기화 사용

```yaml
# .github/workflows/sync-jira.yml
name: Sync to Jira

on:
  issues:
    types: [opened, edited, closed, reopened]

jobs:
  sync:
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-sync-jira.yml@main
    with:
      jira-project-key: YOUR_PROJECT_KEY
    secrets:
      JIRA_BASE_URL: ${{ secrets.JIRA_BASE_URL }}
      JIRA_USER_EMAIL: ${{ secrets.JIRA_USER_EMAIL }}
      JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
```

### 2. n8n 워크플로우 연동

1. GitHub 레포에 Webhook 추가
2. n8n에서 레포별 설정 추가
3. Slack 채널 매핑

자세한 내용은 각 문서를 참고하세요.
