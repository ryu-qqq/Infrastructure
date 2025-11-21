# PR에서 인프라 관리하기 - Atlantis – Terraform (2)

## 🤔 문제: PR에서 Terraform을 어떻게 실행하지?

1편에서 PR 기반 인프라 관리의 장점을 알아봤습니다. 하지만 실제로 어떻게 동작할까요?

**기존 방식의 문제:**
```bash
# 로컬에서 실행
$ terraform plan
$ terraform apply

문제점:
- 각자 다른 Terraform 버전 사용
- 로컬 환경 차이로 인한 오류
- State 파일 동시 수정으로 충돌
- 누가 apply 했는지 추적 어려움
- CI/CD 파이프라인과 별도로 관리
```

**원하는 것:**
- PR에서 자동으로 `terraform plan` 실행
- PR 코멘트에서 plan 결과 확인
- Approve 후 merge하면 자동으로 `terraform apply`
- 모든 과정이 추적 가능하고 재현 가능

## 🎯 해결책: Atlantis

**Atlantis는 PR 기반 Terraform 자동화 서버입니다.**

```
GitHub PR → Atlantis → Terraform → AWS
```

### 핵심 동작 방식

```markdown
1. PR 생성
   └─> Atlantis가 자동으로 terraform plan 실행
       └─> PR 코멘트에 plan 결과 표시

2. 리뷰어가 PR 확인
   └─> plan 결과 보고 승인

3. PR에 "atlantis apply" 코멘트
   └─> Atlantis가 terraform apply 실행
       └─> 결과를 PR 코멘트에 표시

4. Merge
   └─> 변경사항 히스토리에 기록
```

## 🏗️ Atlantis 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                      GitHub                              │
│                                                          │
│  PR 생성 → Webhook → GitHub App                         │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ HTTPS (4141)
                  │
┌─────────────────▼───────────────────────────────────────┐
│              Application Load Balancer                   │
│                                                          │
│  ┌─────────────────────────────────────────────┐       │
│  │  ACM Certificate (*.yourdomain.com)         │       │
│  │  Health Check: /healthz                     │       │
│  └─────────────────────────────────────────────┘       │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ Port 4141
                  │
┌─────────────────▼───────────────────────────────────────┐
│              ECS Fargate (Atlantis)                      │
│                                                          │
│  ┌──────────────────────────────────────────┐          │
│  │  CPU: 512 units (0.5 vCPU)               │          │
│  │  Memory: 1024 MiB (1 GB)                 │          │
│  │  Terraform: v1.9.8                       │          │
│  │  Network Mode: awsvpc                     │          │
│  └──────────────────────────────────────────┘          │
│                                                          │
│  Volumes:                                                │
│  ├─ /home/atlantis/.terraform.d (EFS)                   │
│  └─ /atlantis-data (EFS)                                │
└─────────┬──────────────┬────────────────────────────────┘
          │              │
          │              └──────────────────────┐
          │                                     │
┌─────────▼──────────┐              ┌──────────▼─────────┐
│  Secrets Manager   │              │        EFS         │
│                    │              │                    │
│  GitHub App:       │              │  Terraform State   │
│  - App ID          │              │  Plugin Cache      │
│  - Installation ID │              │  Plan Files        │
│  - Private Key     │              │                    │
└────────────────────┘              └────────────────────┘
```

### 주요 구성 요소

1. **GitHub App**: Webhook을 통해 PR 이벤트 수신
2. **ALB**: HTTPS 트래픽 처리 및 헬스체크
3. **ECS Fargate**: Atlantis 컨테이너 실행
4. **EFS**: Terraform state 및 캐시 저장
5. **Secrets Manager**: GitHub App 인증 정보 보관

## 📝 실제 PR 코멘트 예시

### 1. PR 생성 시 (자동 Plan)

````markdown
**Atlantis Plan Results**

```diff
Terraform used the selected providers to generate the following execution plan.

# aws_security_group_rule.api_https will be created
+ resource "aws_security_group_rule" "api_https" {
    + cidr_blocks              = [
        + "10.0.0.0/16",
      ]
    + description              = "Allow HTTPS from private subnet"
    + from_port                = 443
    + id                       = (known after apply)
    + protocol                 = "tcp"
    + security_group_id        = "sg-0123456789abcdef0"
    + to_port                  = 443
    + type                     = "ingress"
  }

Plan: 1 to add, 0 to change, 0 to destroy.
```

**✅ Validation Results:**
- 🔒 Security Scan: PASSED (0 critical issues)
- 💰 Cost Impact: +$0/month
- 📋 Policy Check: PASSED

---
👉 To apply this plan, comment: `atlantis apply`
````

### 2. Apply 실행 후

````markdown
**Atlantis Apply Results**

```
aws_security_group_rule.api_https: Creating...
aws_security_group_rule.api_https: Creation complete after 2s [id=sgrule-0123456789]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

**✅ Successfully applied!**

**Outputs:**
```hcl
security_group_rule_id = "sgrule-0123456789"
```
````

### 3. 에러 발생 시

````markdown
**Atlantis Plan Failed**

```
Error: Invalid Security Group ID

  on security-groups.tf line 15, in resource "aws_security_group_rule" "api_https":
  15:   security_group_id = "sg-invalid"

The security group ID "sg-invalid" is invalid.
```

**❌ Plan failed**
Please fix the errors and push new changes.
````

## 🚀 Atlantis 설치 가이드 (4단계, 총 12분)

### Phase 1: Terraform 인프라 배포 (5분)

```bash
# 1. Atlantis 디렉토리로 이동
cd terraform/atlantis

# 2. Terraform 초기화
terraform init

# 3. Plan 확인 (배포될 리소스 검토)
terraform plan

# 4. 인프라 배포
terraform apply
# 배포되는 리소스:
# - ECS Cluster, Service, Task Definition
# - Application Load Balancer
# - Security Groups
# - EFS (Terraform state 저장용)
# - CloudWatch Logs
# - IAM Roles

# 5. ALB DNS 이름 확인 (Atlantis URL)
terraform output alb_dns_name
# 출력 예시: atlantis-alb-123456789.ap-northeast-2.elb.amazonaws.com
```

**배포 시간:** 약 5분 (ALB, ECS 서비스 생성 시간 포함)

### Phase 2: GitHub App 생성 (3분)

```bash
# 1. GitHub에서 새 앱 생성
https://github.com/settings/apps/new

# 2. 앱 설정
Name: atlantis-yourcompany
Homepage URL: https://your-atlantis-url.com
Webhook URL: https://your-atlantis-url.com/events
Webhook secret: (랜덤 생성 - 나중에 Secrets Manager에 저장)

# 3. GitHub App Permissions 설정
Repository permissions:
  - Contents: Read & Write
  - Pull requests: Read & Write
  - Issues: Write
  - Webhooks: Read & Write

# 4. 앱 생성 후 메모
App ID: 123456
Installation ID: 789012
Private Key: (다운로드한 .pem 파일 내용)
```

**소요 시간:** 약 3분

### Phase 3: Secrets Manager 설정 (2분)

```bash
# 1. GitHub App 정보를 JSON으로 준비
cat > github-app.json <<EOF
{
  "app_id": "123456",
  "installation_id": "789012",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA...\n-----END RSA PRIVATE KEY-----"
}
EOF

# 2. Secrets Manager에 저장
aws secretsmanager put-secret-value \
  --secret-id atlantis/github-app-v2-prod \
  --secret-string file://github-app.json \
  --region ap-northeast-2

# 3. Webhook Secret 저장
aws secretsmanager put-secret-value \
  --secret-id atlantis/webhook-secret-prod \
  --secret-string "your-webhook-secret-here" \
  --region ap-northeast-2

# 4. 확인
aws secretsmanager get-secret-value \
  --secret-id atlantis/github-app-v2-prod \
  --region ap-northeast-2
```

**소요 시간:** 약 2분

### Phase 4: Atlantis 서비스 재시작 및 테스트 (2분)

```bash
# 1. ECS 서비스 강제 재배포 (새 Secrets 로드)
aws ecs update-service \
  --cluster atlantis-prod \
  --service atlantis-prod \
  --force-new-deployment \
  --region ap-northeast-2

# 2. 헬스체크 확인
curl https://your-atlantis-url.com/healthz
# 응답: {"status":"ok"}

# 3. 로그 확인
aws logs tail /aws/ecs/atlantis-prod --follow

# 4. 테스트 PR 생성
# - 간단한 Terraform 변경사항 PR 생성
# - Atlantis가 자동으로 plan 실행하는지 확인
# - PR 코멘트에 plan 결과가 표시되는지 확인

# 5. Apply 테스트
# - PR에 "atlantis apply" 코멘트 작성
# - Apply 결과 확인
```

**소요 시간:** 약 2분

### 전체 설치 시간

```
Phase 1 (Terraform): 5분
Phase 2 (GitHub App): 3분
Phase 3 (Secrets):    2분
Phase 4 (Test):       2분
─────────────────────────
총 소요 시간:         12분
```

## 🛡️ 보안 고려사항

### 1. GitHub App Permissions (최소 권한 원칙)

```yaml
필수 권한:
  ✅ Contents: Read & Write (코드 읽기/쓰기)
  ✅ Pull requests: Read & Write (PR 코멘트)
  ✅ Issues: Write (이슈 코멘트)

불필요한 권한:
  ❌ Administration (절대 부여 금지)
  ❌ Secrets (부여 금지)
  ❌ Actions (불필요)
```

### 2. Secrets 관리

```hcl
# ❌ 절대 하드코딩 금지
variable "github_token" {
  default = "ghp_xxxxxxxxxxxx"  # 위험!
}

# ✅ Secrets Manager 사용
data "aws_secretsmanager_secret_version" "github_app" {
  secret_id = "atlantis/github-app-v2-prod"
}

locals {
  github_app = jsondecode(data.aws_secretsmanager_secret_version.github_app.secret_string)
}
```

### 3. 네트워크 보안

```hcl
# ECS Task는 Private Subnet에 배치
resource "aws_ecs_service" "atlantis" {
  network_configuration {
    subnets = var.private_subnet_ids  # ✅ Private subnet
    security_groups = [
      aws_security_group.atlantis_task.id
    ]
    assign_public_ip = false  # ✅ Public IP 부여 안 함
  }
}

# ALB는 Public Subnet에 배치
resource "aws_lb" "atlantis" {
  subnets = var.public_subnet_ids  # ✅ Public subnet
  security_groups = [
    aws_security_group.atlantis_alb.id
  ]
}

# Security Group: ALB는 HTTPS만 허용
resource "aws_security_group_rule" "alb_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # HTTPS는 전체 허용
  security_group_id = aws_security_group.atlantis_alb.id
}

# Security Group: ECS Task는 ALB에서만 접근 허용
resource "aws_security_group_rule" "task_from_alb" {
  type                     = "ingress"
  from_port                = 4141
  to_port                  = 4141
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.atlantis_alb.id
  security_group_id        = aws_security_group.atlantis_task.id
}
```

### 4. IAM 권한 (최소 권한)

```hcl
# Atlantis Task Role - Terraform 실행 권한
resource "aws_iam_role_policy" "atlantis_terraform" {
  role = aws_iam_role.atlantis_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # ✅ 필요한 권한만 부여
          "ec2:Describe*",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ecs:UpdateService",
          "ecs:DescribeServices",
          # ... (구체적인 Action 나열)
        ]
        Resource = "*"
      }
    ]
  })
}

# ❌ 절대 금지: 전체 권한 부여
# Action = "*"  # 위험!
```

## 🔧 트러블슈팅

### 문제 1: "Atlantis가 PR 코멘트를 안 달아요"

**증상:**
- PR 생성했는데 Atlantis 반응 없음
- GitHub Webhook은 200 OK

**해결 방법:**
```bash
# 1. Atlantis 로그 확인
aws logs tail /aws/ecs/atlantis-prod --follow

# 2. GitHub App Installation 확인
https://github.com/settings/installations
# → 레포지토리가 제대로 연결되어 있는지 확인

# 3. Webhook 전송 이력 확인
https://github.com/settings/apps/your-app/advanced
# → Recent Deliveries에서 payload와 response 확인

# 4. ECS Task가 실행 중인지 확인
aws ecs describe-services \
  --cluster atlantis-prod \
  --services atlantis-prod

# 일반적인 원인:
# - GitHub App이 레포지토리에 설치 안 됨
# - Webhook URL이 잘못됨
# - Security Group에서 ALB → ECS Task 트래픽 차단
```

### 문제 2: "terraform plan은 되는데 apply가 안 돼요"

**증상:**
- PR 코멘트에 plan 결과는 나옴
- "atlantis apply" 코멘트 작성해도 반응 없음

**해결 방법:**
```bash
# 1. Apply 권한 확인
# atlantis.yaml에서 apply_requirements 확인
cat atlantis.yaml

# 예시: PR이 approved 상태여야 apply 가능
apply_requirements:
  - approved

# 2. PR이 approve 되었는지 확인
# 3. Branch protection rule 확인
# 4. Atlantis 로그에서 에러 메시지 확인
```

### 문제 3: "State lock 에러가 나요"

**증상:**
```
Error: Error acquiring the state lock
Lock Info:
  ID:        12345-6789-abcd-efgh
  Path:      s3://bucket/key
  Operation: OperationTypePlan
  Who:       atlantis@ip-10-0-1-100
  Created:   2024-01-15 10:30:00
```

**해결 방법:**
```bash
# 1. 다른 apply가 진행 중인지 확인
aws dynamodb scan \
  --table-name terraform-lock \
  --region ap-northeast-2

# 2. 강제 unlock (주의: 실제로 다른 apply가 없을 때만!)
terraform force-unlock 12345-6789-abcd-efgh

# 3. Atlantis에서 다시 plan/apply 실행

# 예방 방법:
# - 여러 PR을 동시에 apply 하지 않기
# - Apply가 끝날 때까지 기다리기
# - 긴급 상황 시에만 force-unlock 사용
```

### 문제 4: "plan은 성공하는데 apply에서 에러나요"

**증상:**
- Plan: 1 to add, 0 to change
- Apply: Error creating resource

**해결 방법:**
```bash
# 일반적인 원인:
# 1. IAM 권한 부족
# - Atlantis Task Role에 필요한 권한 추가

# 2. 리소스 이름 중복
# - 고유한 이름 사용 (환경별 prefix/suffix 추가)

# 3. 의존성 문제
# - depends_on 명시적으로 선언

# 4. API Rate Limit
# - 너무 많은 리소스를 한 번에 생성하지 않기
# - Retry 로직 추가
```

## 📊 Atlantis vs 다른 방법 비교

| 구분 | Local 실행 | GitHub Actions | Atlantis |
|------|-----------|----------------|----------|
| **실행 환경** | 각자 로컬 | GitHub Runner | 전용 서버 (ECS) |
| **State 관리** | 각자 관리 (충돌 위험) | Remote backend | Remote backend |
| **PR 통합** | 수동 코멘트 | 자동 (복잡한 워크플로우) | 자동 (간단한 설정) |
| **Apply 권한** | 각자 실행 가능 | GitHub Secret 관리 | PR Approval 연동 |
| **비용** | 무료 | 무료 (분당 과금) | EC2/ECS 비용 (월 $50~100) |
| **장점** | 빠른 테스트 | CI/CD 통합 | PR 중심 워크플로우 |
| **단점** | 팀 협업 어려움 | 복잡한 설정 | 별도 인프라 필요 |
| **추천 시나리오** | 개발/테스트 | 자동 배포 | 팀 협업, PR 리뷰 |

## 💡 모범 사례

### 1. PR 전략

```yaml
# atlantis.yaml
version: 3
automerge: false  # ✅ 자동 머지 비활성화 (리뷰 필수)
delete_source_branch_on_merge: true  # ✅ 머지 후 브랜치 자동 삭제

projects:
  - name: network
    dir: terraform/network
    workflow: default
    apply_requirements:
      - approved  # ✅ PR이 approve되어야만 apply 가능
      - mergeable  # ✅ conflict 없어야 apply 가능

  - name: production-db
    dir: terraform/database
    workflow: production
    apply_requirements:
      - approved
      - mergeable
      - undiverged  # ✅ main과 동기화되어야 apply 가능
```

### 2. 환경별 분리

```hcl
# 환경별로 다른 Atlantis 인스턴스 또는 프로젝트 분리
projects:
  - name: dev-network
    dir: terraform/dev/network
    terraform_version: v1.9.8

  - name: prod-network
    dir: terraform/prod/network
    terraform_version: v1.9.8
    apply_requirements:
      - approved  # Production은 반드시 리뷰 필요
```

### 3. 알림 설정

```hcl
# Slack 알림 연동 (Atlantis에서 지원)
# 또는 GitHub Actions를 통한 알림

# .github/workflows/atlantis-notify.yml
name: Atlantis Notification
on:
  pull_request:
    types: [opened, synchronize]
  issue_comment:
    types: [created]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Send Slack notification
        if: contains(github.event.comment.body, 'atlantis apply')
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "🚀 Atlantis apply started for PR #${{ github.event.issue.number }}"
            }
```

## 🎓 실전 워크플로우 예시

### 시나리오: RDS 인스턴스 타입 변경

```hcl
# 1. 브랜치 생성 및 코드 수정
git checkout -b feat/upgrade-rds-instance

# terraform/database/main.tf
resource "aws_db_instance" "main" {
  identifier     = "prod-db"
- instance_class = "db.t3.medium"   # 기존
+ instance_class = "db.r6g.large"   # 변경

  # ... 다른 설정
}

git add terraform/database/main.tf
git commit -m "feat: Upgrade RDS instance to r6g.large for better performance"
git push origin feat/upgrade-rds-instance
```

**2. PR 생성 → Atlantis 자동 Plan**

````markdown
**Atlantis Plan Results**

```diff
# aws_db_instance.main will be updated in-place
~ resource "aws_db_instance" "main" {
    ~ instance_class = "db.t3.medium" -> "db.r6g.large"

    # (30 unchanged attributes hidden)
}

Plan: 0 to add, 1 to change, 0 to destroy.
```

**💰 Cost Impact (Infracost):**
```
Name                             Monthly Qty  Unit   Monthly Cost
aws_db_instance.main
├─ Database instance (on-demand)         730  hours      $102.19  (was $60.74, +$41.45)
└─ Storage (general purpose SSD, gp3)    100  GB          $11.50

Total:                                                   $113.69  (was $72.24, +$41.45, +57%)
```

**⚠️ Warning:** Cost increase is 57%, exceeding 30% threshold!
**📋 Review Required:** High-risk change (database modification)
````

**3. 팀 리뷰**

```markdown
👤 @senior-dev:
- RDS instance 변경은 재시작이 필요합니다 (약 5분 다운타임)
- 변경 시간을 새벽 2시로 조정하는 게 좋을 것 같습니다
- Blue/Green 배포는 고려했나요?

👤 @dba:
- Multi-AZ라서 다운타임은 짧을 거예요 (1-2분)
- 하지만 트래픽 적은 시간이 안전합니다
- 모니터링 준비 완료

👤 @author:
- 새벽 2시 변경 계획으로 수정하겠습니다
- 롤백 계획:
  1. 문제 발생 시 인스턴스 타입을 다시 t3.medium으로 변경
  2. 예상 롤백 시간: 5분
```

**4. Apply 실행 (새벽 2시)**

```markdown
💬 Comment: atlantis apply

**Atlantis Apply Results**

```
aws_db_instance.main: Modifying... [id=prod-db]
aws_db_instance.main: Still modifying... [1m0s elapsed]
aws_db_instance.main: Still modifying... [2m0s elapsed]
aws_db_instance.main: Modifications complete after 2m15s

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

**✅ Successfully applied!**
**⏱️ Downtime:** ~2 minutes (within SLA)
```

## 🚀 다음 단계

이제 Atlantis를 통해 PR 기반으로 인프라를 안전하게 관리하는 방법을 배웠습니다.

**다음 글에서 다룰 내용:**
1. **Terraform 모듈 패턴** - 재사용 가능한 인프라 컴포넌트 만들기
2. **자동 검증 파이프라인** - tfsec, checkov, OPA, Infracost 상세 가이드
3. **프로덕션 운영 전략** - State 관리, 롤백, 모니터링

## 📚 참고 자료

- [Atlantis 공식 문서](https://www.runatlantis.io/)
- [GitHub App 생성 가이드](https://docs.github.com/en/apps/creating-github-apps)
- [프로젝트의 Atlantis 운영 가이드](../guides/atlantis-operations-guide.md)
- [프로젝트의 Atlantis 설정 가이드](../../terraform/atlantis/README.md)

---

**이전 글:** [AWS Console 클릭 대신 PR로 끝내는 루틴 (1편)](./01-from-console-to-pr.md)
**다음 글:** [Terraform으로 인프라 코드화하기 (3편)](./03-terraform-modules.md)
