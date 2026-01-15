# Infrastructure Atlantis Command

Atlantis 서버 관리 및 Terraform 자동화 작업을 수행합니다.

## 사용법

```
/if:atlantis <action> [options]
```

## 액션

### 서버 관리

```bash
/if:atlantis status      # 서버 상태 확인
/if:atlantis logs        # 로그 모니터링
/if:atlantis restart     # 서비스 재시작
/if:atlantis deploy      # 새 버전 배포
```

### Terraform 작업

```bash
/if:atlantis plan <workspace>    # Plan 실행
/if:atlantis apply <workspace>   # Apply 실행
/if:atlantis unlock <workspace>  # Lock 해제
```

## 아키텍처

```
┌─────────────────────────────────────────────────────┐
│                    GitHub                            │
│   PR → Webhook → Atlantis → Comment (plan/apply)    │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│              ECS (Atlantis Server)                   │
│  ┌─────────┐  ┌─────────┐  ┌─────────────┐        │
│  │ ALB     │→ │ Atlantis│→ │ Terraform   │        │
│  │ (HTTPS) │  │ Server  │  │ Operations  │        │
│  └─────────┘  └─────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│                AWS Resources                         │
│  S3 (tfstate) │ DynamoDB (lock) │ KMS (encryption)  │
└─────────────────────────────────────────────────────┘
```

## 관련 리소스

| 리소스 | 경로 |
|--------|------|
| ECS Task | terraform/environments/prod/atlantis/ |
| ECR Image | terraform/environments/prod/ecr/ |
| ALB | terraform/environments/prod/alb/ |
| IAM Role | terraform/environments/prod/iam/ |

## 헬스체크

```bash
# 서버 상태 확인
./scripts/atlantis/check-atlantis-health.sh

# 로그 모니터링
./scripts/atlantis/monitor-atlantis-logs.sh

# 서비스 재시작
./scripts/atlantis/restart-atlantis.sh
```

## Docker 이미지

```bash
# 빌드 및 푸시
./scripts/build-and-push.sh

# 특정 버전
ATLANTIS_VERSION=v0.30.0 ./scripts/build-and-push.sh

# 커스텀 태그
CUSTOM_TAG=prod ./scripts/build-and-push.sh
```

## 설정 파일

### atlantis.yaml

```yaml
version: 3
projects:
  - name: prod-vpc
    dir: terraform/environments/prod/vpc
    workspace: default
    terraform_version: v1.5.0
    autoplan:
      when_modified: ["*.tf", "../modules/**/*.tf"]
      enabled: true
```

### 환경 변수

| 변수 | 설명 |
|------|------|
| ATLANTIS_GH_TOKEN | GitHub 토큰 |
| ATLANTIS_GH_WEBHOOK_SECRET | Webhook 시크릿 |
| ATLANTIS_REPO_ALLOWLIST | 허용 레포 목록 |
| AWS_DEFAULT_REGION | AWS 리전 |

## 트러블슈팅

### Lock 해제

```bash
# 특정 워크스페이스 잠금 해제
atlantis unlock -p project-name -w workspace

# 강제 해제 (주의)
/if:atlantis unlock prod-vpc --force
```

### Plan 실패 시

1. 로그 확인: `/if:atlantis logs`
2. State 확인: `terraform state list`
3. Lock 확인: DynamoDB terraform-lock 테이블
4. 권한 확인: IAM 역할 정책

### Apply 실패 시

1. Plan 결과 재확인
2. State drift 확인
3. 리소스 충돌 확인
4. 롤백 준비

## 예제

```bash
# 상태 확인
/if:atlantis status

# prod VPC plan 실행
/if:atlantis plan prod-vpc

# 로그 실시간 확인
/if:atlantis logs --follow

# 새 버전 배포
/if:atlantis deploy --version v0.30.0
```

## 보안 고려사항

- GitHub Webhook Secret 필수
- IAM Role 최소 권한 원칙
- TLS/HTTPS 통신
- Secrets Manager 연동
- CloudTrail 로깅

## 관련 커맨드

- `/if:module` - 모듈 생성/관리
- `/if:validate` - 거버넌스 검증
- `/if:shared` - 공유 리소스 관리
