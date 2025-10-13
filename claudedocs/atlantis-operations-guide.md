# Atlantis 운영 가이드

> 작성일: 2025-10-13
> 버전: 1.0
> 담당: Infrastructure Team

## 목차

1. [개요](#개요)
2. [인프라 구성](#인프라-구성)
3. [레포지토리 관리](#레포지토리-관리)
4. [Atlantis 업그레이드](#atlantis-업그레이드)
5. [트러블슈팅](#트러블슈팅)
6. [로그 분석](#로그-분석)
7. [참고 자료](#참고-자료)

---

## 개요

### Atlantis란?

Atlantis는 Pull Request를 통해 Terraform을 자동으로 실행하는 도구입니다. PR에 코멘트를 작성하면 `terraform plan`과 `terraform apply`를 자동으로 실행하여 인프라 변경사항을 관리할 수 있습니다.

### 현재 구성

- **배포 환경**: AWS ECS Fargate
- **클러스터**: atlantis-prod
- **서비스**: atlantis-prod (1 task)
- **URL**: https://atlantis.set-of.com
- **GitHub App ID**: 2105317
- **Webhook URL**: https://atlantis.set-of.com/events

### 관리 대상 레포지토리

현재 Atlantis가 관리하는 레포지토리:

1. **Infrastructure** - Terraform 인프라 코드
2. **FileFlow** - 파일 관리 서비스
3. **AuthHub** - 인증 서비스
4. **Crawler** - 크롤링 서비스

---

## 인프라 구성

### 아키텍처

```
GitHub PR → GitHub Webhook → ALB → ECS Fargate (Atlantis) → Terraform → AWS Resources
                                      ↓
                                  EFS (State)
                                      ↓
                              Secrets Manager (Credentials)
                                      ↓
                              CloudWatch Logs
```

### 주요 컴포넌트

#### 1. ECS Fargate
- **Task Definition**: atlantis-prod
- **CPU**: 512 (0.5 vCPU)
- **Memory**: 1024 MB (1 GB)
- **컨테이너 포트**: 4141
- **Health Check**: `/healthz` endpoint

#### 2. Application Load Balancer (ALB)
- **Target Group**: atl-20251011072359287200000001
- **Health Check Path**: `/healthz`
- **Health Check Interval**: 30초
- **SSL/TLS**: ACM 인증서 사용

#### 3. EFS (Elastic File System)
- **Mount Point**: `/home/atlantis/.atlantis`
- **용도**: Terraform state 및 플랜 파일 저장
- **암호화**: 전송 중 암호화 활성화 (TLS)

#### 4. Secrets Manager
두 개의 시크릿 저장:

**atlantis/github-app-v2-prod**:
```json
{
  "app_id": "GitHub App ID",
  "installation_id": "Installation ID",
  "private_key": "Private Key (PEM format)"
}
```

**atlantis/webhook-secret-v2-prod**:
```json
{
  "webhook_secret": "Webhook Secret"
}
```

#### 5. CloudWatch Logs
- **Log Group**: `/ecs/atlantis-prod`
- **보관 기간**: 7일
- **로그 레벨**: debug

---

## 레포지토리 관리

### 레포지토리 추가하기

새로운 레포지토리를 Atlantis에 추가하는 절차입니다.

#### 1단계: repos.yaml 파일 수정

`terraform/atlantis/repos.yaml` 파일을 편집합니다:

```yaml
repos:
  # 기존 레포지토리들...

  # 새로운 레포지토리 추가
  - id: github.com/ryu-qqq/new-repository
    allowed_overrides: [workflow, apply_requirements]
    allowed_workflows: [default, custom]
    allow_custom_workflows: true
```

**설정 옵션 설명**:
- `id`: GitHub 레포지토리 전체 경로
- `allowed_overrides`: 레포지토리에서 오버라이드 가능한 설정
- `allowed_workflows`: 사용 가능한 워크플로우 목록
- `allow_custom_workflows`: 커스텀 워크플로우 허용 여부

#### 2단계: 환경변수 확인

`ATLANTIS_REPO_ALLOWLIST`가 organization 전체를 허용하는지 확인:

```bash
aws ecs describe-task-definition \
  --task-definition atlantis-prod \
  --region ap-northeast-2 \
  --query 'taskDefinition.containerDefinitions[0].environment[?name==`ATLANTIS_REPO_ALLOWLIST`]'
```

결과 예시:
```json
[
  {
    "name": "ATLANTIS_REPO_ALLOWLIST",
    "value": "github.com/ryu-qqq/*"
  }
]
```

#### 3단계: Docker 이미지 빌드 및 푸시

repos.yaml 변경사항을 포함한 새로운 이미지를 빌드합니다:

```bash
cd terraform/atlantis

# Docker 이미지 빌드
docker build -t atlantis:latest .

# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  646886795421.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 태그
docker tag atlantis:latest \
  646886795421.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis-prod:latest

# ECR에 푸시
docker push \
  646886795421.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis-prod:latest
```

#### 4단계: ECS 서비스 업데이트

새로운 Task Definition을 배포합니다:

```bash
# Terraform으로 배포
cd terraform/atlantis
terraform init
terraform plan
terraform apply

# 또는 AWS CLI로 서비스 강제 재배포
aws ecs update-service \
  --cluster atlantis-prod \
  --service atlantis-prod \
  --force-new-deployment \
  --region ap-northeast-2
```

#### 5단계: 검증

새 레포지토리에서 테스트 PR을 생성하여 Atlantis가 정상 작동하는지 확인:

1. 테스트 PR 생성
2. PR에 `atlantis plan` 코멘트 작성
3. Atlantis가 plan 결과를 코멘트로 남기는지 확인
4. CloudWatch 로그에서 레포지토리 인식 여부 확인

```bash
aws logs tail /ecs/atlantis-prod \
  --since 10m \
  --filter-pattern "new-repository" \
  --region ap-northeast-2
```

### 레포지토리 제거하기

#### 1단계: repos.yaml에서 제거

해당 레포지토리 설정을 `terraform/atlantis/repos.yaml`에서 삭제합니다.

#### 2단계: Docker 이미지 재빌드 및 배포

추가할 때와 동일한 절차로 이미지를 빌드하고 배포합니다.

#### 3단계: GitHub App 권한 제거 (선택사항)

GitHub에서 해당 레포지토리의 Atlantis App 설치를 제거할 수 있습니다:

1. GitHub Organization Settings → Applications
2. Atlantis App 선택
3. Repository access에서 해당 레포지토리 제거

---

## Atlantis 업그레이드

### Atlantis 버전 업그레이드

Atlantis 버전을 업그레이드하는 절차입니다.

#### 1단계: 릴리스 노트 확인

[Atlantis GitHub Releases](https://github.com/runatlantis/atlantis/releases)에서 최신 버전의 변경사항을 확인합니다.

**주의사항**:
- Breaking changes 확인
- 새로운 환경변수나 설정 요구사항 확인
- 마이그레이션 가이드 확인

#### 2단계: variables.tf 수정

`terraform/atlantis/variables.tf`에서 `atlantis_version` 변수를 업데이트합니다:

```hcl
variable "atlantis_version" {
  description = "Atlantis version to deploy"
  type        = string
  default     = "v0.28.0"  # 새 버전으로 변경
}
```

#### 3단계: Dockerfile 확인

`terraform/atlantis/Dockerfile`에서 기본 이미지 버전을 확인합니다:

```dockerfile
FROM ghcr.io/runatlantis/atlantis:v0.28.0
```

필요시 Dockerfile도 업데이트합니다.

#### 4단계: 로컬 테스트 (권장)

프로덕션 배포 전 로컬에서 테스트:

```bash
cd terraform/atlantis

# Docker 이미지 빌드
docker build -t atlantis:test .

# 로컬 실행 테스트
docker run -p 4141:4141 \
  -e ATLANTIS_GH_APP_ID="your_app_id" \
  -e ATLANTIS_ATLANTIS_URL="http://localhost:4141" \
  atlantis:test server
```

#### 5단계: 프로덕션 배포

Terraform을 통해 배포:

```bash
cd terraform/atlantis

# Terraform 실행
terraform init
terraform plan  # 변경사항 확인
terraform apply # 배포

# 배포 상태 확인
aws ecs describe-services \
  --cluster atlantis-prod \
  --services atlantis-prod \
  --region ap-northeast-2
```

#### 6단계: 헬스체크 확인

배포 후 Atlantis가 정상 작동하는지 확인:

```bash
# ALB Health Check 상태
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-2:646886795421:targetgroup/atl-20251011072359287200000001/2c46e9934484e453 \
  --region ap-northeast-2

# ECS Task 상태
aws ecs list-tasks \
  --cluster atlantis-prod \
  --service-name atlantis-prod \
  --region ap-northeast-2
```

#### 7단계: 기능 테스트

테스트 PR을 생성하여 기본 기능을 확인:

1. Infrastructure 레포지토리에 테스트 브랜치 생성
2. 사소한 변경 후 PR 생성
3. `atlantis plan` 코멘트로 plan 실행 확인
4. `atlantis apply` 코멘트로 apply 실행 확인

#### 롤백 절차

업그레이드 중 문제 발생 시:

```bash
# 이전 Task Definition으로 롤백
aws ecs update-service \
  --cluster atlantis-prod \
  --service atlantis-prod \
  --task-definition atlantis-prod:<previous-revision> \
  --region ap-northeast-2

# 또는 Terraform state에서 이전 버전으로 복구
cd terraform/atlantis
git log  # 이전 커밋 확인
git checkout <previous-commit>
terraform apply
```

---

## 트러블슈팅

### 일반적인 문제 및 해결 방법

#### 1. Atlantis가 PR에 응답하지 않음

**증상**: PR에 `atlantis plan` 코멘트를 작성해도 반응이 없음

**원인 및 해결**:

1. **GitHub Webhook 전달 실패**
   ```bash
   # ALB 타겟 헬스 확인
   aws elbv2 describe-target-health \
     --target-group-arn <target-group-arn> \
     --region ap-northeast-2
   ```
   - Unhealthy 상태면 ECS Task 로그 확인

2. **Webhook Secret 불일치**
   ```bash
   # CloudWatch 로그에서 "signature" 또는 "webhook" 검색
   aws logs tail /ecs/atlantis-prod \
     --since 30m \
     --filter-pattern "signature" \
     --region ap-northeast-2
   ```
   - Secret 불일치 시 Secrets Manager 업데이트 필요

3. **레포지토리 Allowlist 미등록**
   ```bash
   # repos.yaml 확인
   cat terraform/atlantis/repos.yaml

   # ATLANTIS_REPO_ALLOWLIST 확인
   aws ecs describe-task-definition \
     --task-definition atlantis-prod \
     --query 'taskDefinition.containerDefinitions[0].environment[?name==`ATLANTIS_REPO_ALLOWLIST`]'
   ```

4. **GitHub App 권한 부족**
   - GitHub Organization Settings → Applications → Atlantis
   - Repository access 및 Permissions 확인
   - 필요 권한: Contents (Read/Write), Pull Requests (Read/Write), Issues (Write)

#### 2. `terraform plan` 실패

**증상**: Atlantis가 plan을 실행하지만 실패함

**원인 및 해결**:

1. **AWS 자격증명 오류**
   ```bash
   # ECS Task Role 확인
   aws iam get-role --role-name atlantis-ecs-task-role-prod

   # 필요한 정책이 연결되어 있는지 확인
   aws iam list-attached-role-policies --role-name atlantis-ecs-task-role-prod
   ```

2. **Terraform 버전 불일치**
   - PR의 `.terraform-version` 파일 확인
   - Atlantis Dockerfile의 Terraform 버전과 일치하는지 확인

3. **Backend 초기화 실패**
   ```bash
   # S3 Backend 접근 권한 확인
   aws s3 ls s3://terraform-state-bucket-name/

   # DynamoDB Lock 테이블 확인
   aws dynamodb describe-table --table-name terraform-locks
   ```

#### 3. ECS Task가 계속 재시작됨

**증상**: ECS 서비스에서 Task가 반복적으로 중지되고 재시작됨

**원인 및 해결**:

1. **Health Check 실패**
   ```bash
   # 컨테이너 로그 확인
   aws logs tail /ecs/atlantis-prod \
     --since 15m \
     --region ap-northeast-2

   # Health check endpoint 직접 확인 (ECS Exec 필요 시)
   curl http://localhost:4141/healthz
   ```

2. **메모리 부족 (OOM)**
   ```bash
   # CloudWatch 메트릭 확인
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ECS \
     --metric-name MemoryUtilization \
     --dimensions Name=ServiceName,Value=atlantis-prod \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Average \
     --region ap-northeast-2
   ```
   - Memory 사용량이 90% 이상이면 Task Definition의 메모리 증가 필요

3. **EFS 마운트 실패**
   ```bash
   # EFS 마운트 타겟 상태 확인
   aws efs describe-mount-targets \
     --file-system-id <efs-id> \
     --region ap-northeast-2

   # VPC 보안그룹 확인 (NFS 포트 2049 허용 필요)
   ```

#### 4. `atlantis apply`가 승인되지 않음

**증상**: apply 명령어가 "PR not approved" 오류 반환

**원인 및 해결**:

1. **PR Approval 설정 확인**
   - `repos.yaml`에서 `apply_requirements` 확인
   - GitHub Branch Protection Rules 확인

2. **Approval이 무효화됨**
   - PR에 새로운 커밋이 푸시되면 이전 approval이 무효화될 수 있음
   - 다시 approve 필요

#### 5. Secrets Manager 접근 오류

**증상**: "AccessDeniedException" 로그 또는 GitHub 인증 실패

**원인 및 해결**:

```bash
# Task Execution Role의 권한 확인
aws iam get-role-policy \
  --role-name atlantis-ecs-task-execution-role-prod \
  --policy-name SecretsManagerAccess

# Secret 값 확인 (관리자 권한 필요)
aws secretsmanager get-secret-value \
  --secret-id atlantis/github-app-v2-prod \
  --region ap-northeast-2

# Secret이 존재하지 않으면 재생성
terraform -chdir=terraform/atlantis apply -target=aws_secretsmanager_secret_version.atlantis-github-app
```

---

## 로그 분석

### CloudWatch Logs 조회

#### 기본 명령어

```bash
# 최근 1시간 로그 확인
aws logs tail /ecs/atlantis-prod \
  --since 1h \
  --region ap-northeast-2

# 실시간 로그 스트리밍
aws logs tail /ecs/atlantis-prod \
  --follow \
  --region ap-northeast-2

# 특정 시간 범위 로그
aws logs tail /ecs/atlantis-prod \
  --since 2025-10-13T00:00:00 \
  --until 2025-10-13T23:59:59 \
  --region ap-northeast-2
```

#### 필터링

```bash
# 특정 레포지토리 관련 로그
aws logs tail /ecs/atlantis-prod \
  --since 30m \
  --filter-pattern "FileFlow" \
  --region ap-northeast-2

# 에러 로그만 확인
aws logs tail /ecs/atlantis-prod \
  --since 1h \
  --filter-pattern "level=error" \
  --region ap-northeast-2

# 특정 PR 번호 관련 로그
aws logs tail /ecs/atlantis-prod \
  --since 1h \
  --filter-pattern "pull=42" \
  --region ap-northeast-2

# Plan 실행 로그
aws logs tail /ecs/atlantis-prod \
  --since 1h \
  --filter-pattern "terraform plan" \
  --region ap-northeast-2
```

### 로그 해석

#### 정상 동작 로그 예시

**1. PR 이벤트 수신**
```json
{
  "level": "info",
  "ts": "2025-10-13T10:00:00.000Z",
  "msg": "Received webhook event",
  "json": {
    "repo": "ryu-qqq/FileFlow",
    "pull": "42",
    "action": "opened"
  }
}
```

**2. Plan 실행**
```json
{
  "level": "info",
  "ts": "2025-10-13T10:00:05.000Z",
  "msg": "Running plan",
  "json": {
    "repo": "ryu-qqq/FileFlow",
    "pull": "42",
    "workspace": "default"
  }
}
```

**3. Plan 성공**
```json
{
  "level": "info",
  "ts": "2025-10-13T10:00:30.000Z",
  "msg": "Plan succeeded",
  "json": {
    "repo": "ryu-qqq/FileFlow",
    "pull": "42",
    "workspace": "default"
  }
}
```

#### 오류 로그 패턴

**1. 인증 오류**
```json
{
  "level": "error",
  "ts": "2025-10-13T10:00:00.000Z",
  "msg": "GitHub authentication failed",
  "error": "401 Unauthorized"
}
```
→ GitHub App 자격증명 확인 필요 (Secrets Manager)

**2. Terraform 실행 오류**
```json
{
  "level": "error",
  "ts": "2025-10-13T10:00:15.000Z",
  "msg": "Terraform plan failed",
  "error": "Error: Provider configuration not present"
}
```
→ Terraform 설정 오류 또는 AWS 자격증명 문제

**3. Webhook 서명 오류**
```json
{
  "level": "error",
  "ts": "2025-10-13T10:00:00.000Z",
  "msg": "Webhook signature verification failed"
}
```
→ Webhook Secret 불일치

### 로그 데이터 내보내기

장기 보관이나 분석을 위해 로그를 내보낼 수 있습니다:

```bash
# 로그를 파일로 저장
aws logs tail /ecs/atlantis-prod \
  --since 24h \
  --format short \
  --region ap-northeast-2 > atlantis-logs-$(date +%Y%m%d).log

# JSON 형식으로 저장
aws logs tail /ecs/atlantis-prod \
  --since 24h \
  --format json \
  --region ap-northeast-2 > atlantis-logs-$(date +%Y%m%d).json
```

### CloudWatch Insights 쿼리

고급 분석을 위한 CloudWatch Insights 쿼리 예시:

**1. 시간대별 요청 수**
```
fields @timestamp, @message
| filter @message like /Received webhook/
| stats count() by bin(5m)
```

**2. 레포지토리별 Plan 실행 횟수**
```
fields @timestamp, json.repo
| filter @message like /Running plan/
| stats count() by json.repo
```

**3. 에러 빈도 분석**
```
fields @timestamp, level, @message
| filter level = "error"
| stats count() by @message
```

**4. Plan 실행 시간 분석**
```
fields @timestamp, json.repo, json.pull
| filter @message like /Plan succeeded/ or @message like /Running plan/
| stats count() by json.repo
```

---

## 참고 자료

### 공식 문서
- [Atlantis 공식 문서](https://www.runatlantis.io/docs/)
- [Atlantis Server Configuration](https://www.runatlantis.io/docs/server-configuration.html)
- [Atlantis Repo-level Configuration](https://www.runatlantis.io/docs/repo-level-atlantis-yaml.html)
- [GitHub Apps 가이드](https://docs.github.com/en/apps)

### 내부 리소스
- **Terraform 코드**: `/terraform/atlantis/`
- **repos.yaml**: `/terraform/atlantis/repos.yaml`
- **CloudWatch Logs**: `/ecs/atlantis-prod`
- **ECR Repository**: `646886795421.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis-prod`

### 긴급 연락처
- **Infrastructure Team**: [팀 연락처]
- **On-call**: [On-call 연락처]
- **Slack Channel**: #infrastructure

### 변경 이력

| 날짜 | 버전 | 변경 내용 | 작성자 |
|------|------|-----------|--------|
| 2025-10-13 | 1.0 | 초기 문서 작성 | Infrastructure Team |

---

## 부록

### 유용한 스크립트

#### Atlantis 재시작 스크립트
```bash
#!/bin/bash
# restart-atlantis.sh

aws ecs update-service \
  --cluster atlantis-prod \
  --service atlantis-prod \
  --force-new-deployment \
  --region ap-northeast-2

echo "Atlantis 재배포 시작됨. 약 2-3분 소요됩니다."
```

#### 헬스체크 스크립트
```bash
#!/bin/bash
# check-atlantis-health.sh

echo "=== ECS Service Status ==="
aws ecs describe-services \
  --cluster atlantis-prod \
  --services atlantis-prod \
  --region ap-northeast-2 \
  --query 'services[0].[serviceName,status,runningCount,desiredCount]' \
  --output table

echo -e "\n=== Target Health ==="
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:ap-northeast-2:646886795421:targetgroup/atl-20251011072359287200000001/2c46e9934484e453 \
  --region ap-northeast-2 \
  --query 'TargetHealthDescriptions[0].TargetHealth' \
  --output table

echo -e "\n=== Recent Logs ==="
aws logs tail /ecs/atlantis-prod \
  --since 5m \
  --region ap-northeast-2 | tail -20
```

#### 로그 모니터링 스크립트
```bash
#!/bin/bash
# monitor-atlantis-logs.sh

# 실시간 에러 로그 모니터링
aws logs tail /ecs/atlantis-prod \
  --follow \
  --filter-pattern "level=error" \
  --region ap-northeast-2 \
  --format short
```

---

**문서 끝**
