# Atlantis Terraform Configuration

Atlantis 서버를 AWS ECS Fargate에 배포하기 위한 Terraform 구성입니다.

## 구성 요소

### ECS 인프라 (ecs.tf)
- **ECS 클러스터**: Fargate 기반 클러스터
  - Container Insights 활성화
  - Fargate 및 Fargate Spot 용량 제공자 구성
- **출력값**: 클러스터 ID, 이름, ARN

### IAM 역할 (iam.tf)
- **Task Execution Role**: ECS가 컨테이너 이미지 풀링 및 로그 게시에 사용
  - AWS 관리형 정책: `AmazonECSTaskExecutionRolePolicy`
  - ECR KMS 복호화 권한
  - ECR 이미지 접근 권한

- **Task Role**: Atlantis 컨테이너가 Terraform 작업 수행 시 사용
  - Terraform State 접근 (S3)
  - DynamoDB 상태 잠금
  - Terraform Plan 작업 권한 (읽기 전용)
  - CloudWatch Logs 권한

### ECS Task Definition (task-definition.tf)
- **컨테이너 구성**:
  - CPU: 512 units (변경 가능)
  - Memory: 1024 MiB (변경 가능)
  - 포트: 4141 (기본값)
  - Health Check: `/healthz` 엔드포인트
  - 로그: CloudWatch Logs (7일 보관)

- **환경 변수** (기본값):
  - `ATLANTIS_PORT`: 4141
  - `ATLANTIS_ATLANTIS_URL`: https://atlantis.example.com
  - `ATLANTIS_REPO_ALLOWLIST`: github.com/*
  - `ATLANTIS_LOG_LEVEL`: info

### ECR 저장소 (ecr.tf)
- Docker 이미지 저장소
- KMS 암호화
- 푸시 시 이미지 스캔
- 라이프사이클 정책 (최근 10개 버전 유지)

### KMS 키 (kms.tf)
- ECR 암호화용 KMS 키
- 자동 키 회전 활성화
- ECR 및 ECS 서비스 접근 권한

### Application Load Balancer (alb.tf)
- **ALB 보안 그룹**:
  - HTTP (80) 및 HTTPS (443) 인바운드 허용
  - 모든 아웃바운드 트래픽 허용
  - 설정 가능한 CIDR 블록 제한

- **ECS Task 보안 그룹**:
  - ALB로부터의 컨테이너 포트 인바운드 허용
  - 모든 아웃바운드 트래픽 허용

- **Application Load Balancer**:
  - Internet-facing 구성
  - HTTP/2 활성화
  - Cross-zone 로드 밸런싱 활성화
  - Public 서브넷에 배포

- **Target Group**:
  - IP 타겟 타입 (Fargate용)
  - 헬스체크 경로: `/healthz`
  - 설정 가능한 헬스체크 파라미터

- **리스너**:
  - HTTP (80): HTTPS로 영구 리다이렉트
  - HTTPS (443): TLS 1.3 지원, ACM 인증서 사용

## 사용 방법

### 1. 사전 요구사항
- AWS CLI 구성 완료
- Terraform >= 1.5.0
- 적절한 AWS IAM 권한

### 2. 초기화
```bash
terraform init
```

### 3. 구성 검증
```bash
terraform validate
terraform fmt
```

### 4. 배포 계획 확인
```bash
terraform plan
```

### 5. 리소스 배포
```bash
terraform apply
```

## 변수 설정

### terraform.tfvars 생성

주요 변수는 `variables.tf`에 정의되어 있습니다. 실제 값은 `terraform.tfvars` 파일에 설정합니다:

```bash
# terraform.tfvars.example을 복사하여 시작
cp terraform.tfvars.example terraform.tfvars

# 실제 값으로 수정
vi terraform.tfvars
```

**⚠️ 주의**: `terraform.tfvars`는 민감한 정보를 포함하므로 `.gitignore`에 포함되어 있습니다.

### 필수 변수

| 변수 | 설명 | 예시 | 확인 방법 |
|------|------|------|----------|
| `vpc_id` | VPC ID | `vpc-0f162b9e588276e09` | `aws ec2 describe-vpcs` |
| `public_subnet_ids` | Public 서브넷 ID 목록 | `["subnet-xxx", "subnet-yyy"]` | `aws ec2 describe-subnets` |
| `private_subnet_ids` | Private 서브넷 ID 목록 | `["subnet-zzz", "subnet-aaa"]` | `aws ec2 describe-subnets` |
| `acm_certificate_arn` | ACM 인증서 ARN | `arn:aws:acm:...` | `aws acm list-certificates` |
| `allowed_cidr_blocks` | ALB 접근 허용 CIDR | `["0.0.0.0/0"]` | 보안 정책에 따라 설정 |

### 선택적 변수 (기본값 있음)

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `environment` | 환경 이름 | `prod` |
| `aws_region` | AWS 리전 | `ap-northeast-2` |
| `atlantis_version` | Atlantis 버전 | `v0.30.0` |
| `atlantis_cpu` | Task CPU | `512` |
| `atlantis_memory` | Task Memory (MiB) | `1024` |
| `atlantis_container_port` | 컨테이너 포트 | `4141` |
| `atlantis_url` | Atlantis 접속 URL | `https://atlantis.example.com` |
| `atlantis_repo_allowlist` | 허용된 리포지토리 | `github.com/ryu-qqq/*` |
| `alb_enable_deletion_protection` | ALB 삭제 보호 | `false` |
| `alb_health_check_path` | 헬스체크 경로 | `/healthz` |

### ACM 인증서 설정

현재 사용 중인 ACM 인증서:
- **도메인**: `*.set-of.com` 및 `set-of.com`
- **타입**: AWS-issued (자동 갱신 가능)
- **상태**: ISSUED
- **유효기간**: 2026-09-05까지

인증서 확인:
```bash
aws acm list-certificates --region ap-northeast-2 \
  --query 'CertificateSummaryList[?Status==`ISSUED`]'
```

## 출력값

배포 후 다음 값들이 출력됩니다:
- ECR 저장소 URL 및 ARN
- ECS 클러스터 정보
- IAM 역할 ARN
- Task Definition ARN 및 버전
- CloudWatch Log Group 이름
- **ALB DNS 이름** (atlantis_alb_dns_name)
- **ALB Zone ID** (atlantis_alb_zone_id)
- **Target Group ARN** (atlantis_target_group_arn)
- **보안 그룹 ID** (ALB 및 ECS Tasks)

## 주의사항

1. **AWS 자격 증명**: Terraform 실행 전 AWS 자격 증명이 올바르게 구성되어 있어야 합니다.
2. **환경 변수**: Task Definition의 환경 변수는 실제 환경에 맞게 수정이 필요합니다.
3. **보안**: 민감한 정보는 AWS Secrets Manager 또는 Parameter Store를 사용하는 것을 권장합니다.
4. **비용**: Fargate는 실행 시간에 따라 비용이 발생합니다.

## 다음 단계

이 구성으로 생성된 리소스:
- ✅ ECS 클러스터
- ✅ Task Definition
- ✅ IAM 역할 및 정책
- ✅ CloudWatch Log Group
- ✅ **Application Load Balancer 및 관련 리소스**
- ✅ **보안 그룹 (ALB 및 ECS Tasks)**
- ✅ **Target Group 및 헬스체크**
- ✅ **HTTP/HTTPS 리스너**

추가로 필요한 작업 (Phase 1 완료를 위해):
- [ ] VPC 및 서브넷 구성 (또는 기존 VPC 사용)
- [ ] ACM 인증서 발급
- [ ] ECS 서비스 정의 및 배포
- [ ] Route53 DNS 설정

## 🔒 Security Considerations

### 1. IAM 역할 최소 권한 원칙

**ECS Task Role 권한 최소화**:
```hcl
# ❌ 잘못된 예: 과도한 권한
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*"
}

# ✅ 올바른 예: 필요한 권한만 부여
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject"
  ],
  "Resource": "arn:aws:s3:::terraform-state-bucket/*"
}
```

**필수 권한 검증**:
```bash
# IAM 역할 정책 확인
aws iam get-role-policy \
  --role-name atlantis-task-role \
  --policy-name atlantis-policy \
  --region ap-northeast-2

# 실제 사용되는 권한 분석 (Access Analyzer)
aws accessanalyzer list-findings \
  --analyzer-arn arn:aws:access-analyzer:ap-northeast-2:ACCOUNT_ID:analyzer/console \
  --filter '{"resource.id":{"contains":["atlantis"]}}' \
  --region ap-northeast-2
```

### 2. Secrets Manager 사용

**중요 정보는 반드시 Secrets Manager에 저장**:

```bash
# GitHub Token 저장
aws secretsmanager create-secret \
  --name atlantis/github-token \
  --description "GitHub personal access token for Atlantis" \
  --secret-string "ghp_xxxxxxxxxxxx" \
  --kms-key-id alias/atlantis-secrets \
  --region ap-northeast-2

# Webhook Secret 저장
aws secretsmanager create-secret \
  --name atlantis/webhook-secret \
  --description "GitHub webhook secret for Atlantis" \
  --secret-string "$(openssl rand -hex 32)" \
  --kms-key-id alias/atlantis-secrets \
  --region ap-northeast-2

# Secrets 값 확인
aws secretsmanager get-secret-value \
  --secret-id atlantis/github-token \
  --query SecretString --output text \
  --region ap-northeast-2
```

**ECS Task Definition에서 참조**:
```hcl
container_definitions = jsonencode([{
  secrets = [
    {
      name      = "ATLANTIS_GH_TOKEN"
      valueFrom = "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:atlantis/github-token"
    },
    {
      name      = "ATLANTIS_GH_WEBHOOK_SECRET"
      valueFrom = "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:atlantis/webhook-secret"
    }
  ]
}])
```

### 3. 보안 그룹 최소화

**인바운드 규칙 제한**:
```hcl
# ALB 보안 그룹: GitHub Webhook IP만 허용
resource "aws_security_group_rule" "alb_github" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [
    "140.82.112.0/20",   # GitHub Hooks
    "143.55.64.0/20",    # GitHub Hooks
    "192.30.252.0/22",   # GitHub Hooks
  ]
  security_group_id = aws_security_group.alb.id
}

# ECS Task 보안 그룹: ALB에서만 접근 허용
resource "aws_security_group_rule" "ecs_from_alb" {
  type                     = "ingress"
  from_port                = 4141
  to_port                  = 4141
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_tasks.id
}
```

**아웃바운드 규칙 제한**:
```hcl
# 필요한 서비스만 허용
resource "aws_security_group_rule" "ecs_to_github" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # GitHub API 접근
  description       = "Allow outbound HTTPS to GitHub"
  security_group_id = aws_security_group.ecs_tasks.id
}
```

**보안 그룹 규칙 검증**:
```bash
# 보안 그룹 규칙 확인
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=atlantis-*" \
  --region ap-northeast-2 \
  --query 'SecurityGroups[*].{Name:GroupName,InboundRules:IpPermissions,OutboundRules:IpPermissionsEgress}'

# 불필요한 0.0.0.0/0 규칙 검색
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=atlantis-*" \
  --region ap-northeast-2 \
  --query 'SecurityGroups[?IpPermissions[?contains(IpRanges[].CidrIp, `0.0.0.0/0`)]]'
```

### 4. 네트워크 격리

**Private Subnet 배치**:
```hcl
# ECS Task는 반드시 Private Subnet에 배치
resource "aws_ecs_service" "atlantis" {
  network_configuration {
    subnets          = data.aws_subnets.private.ids  # ✅ Private
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false  # ✅ Public IP 비활성화
  }
}

# ALB는 Public Subnet에 배치
resource "aws_lb" "atlantis" {
  subnets         = data.aws_subnets.public.ids  # Public
  internal        = false  # Internet-facing
}
```

**VPC Endpoint 사용** (비용 절감 + 보안 강화):
```hcl
# ECR VPC Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-2.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
}

# Secrets Manager VPC Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-2.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
}
```

### 5. 감사 및 로깅

**CloudTrail 활성화**:
```bash
# Atlantis IAM 역할 활동 확인
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=atlantis-task-role \
  --max-results 50 \
  --region ap-northeast-2

# S3 State 파일 접근 이력
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=terraform-state-bucket \
  --max-results 50 \
  --region ap-northeast-2
```

**CloudWatch Logs Insights 쿼리**:
```sql
-- Terraform plan/apply 실행 이력
fields @timestamp, @message
| filter @message like /atlantis (plan|apply)/
| sort @timestamp desc
| limit 100

-- 실패한 인증 시도
fields @timestamp, @message
| filter @message like /(401|403|Unauthorized)/
| sort @timestamp desc
| limit 50

-- GitHub Webhook 수신 이력
fields @timestamp, @message
| filter @message like /webhook/
| stats count() by bin(5m)
```

**CloudWatch Alarms 설정**:
```hcl
# 인증 실패 알람
resource "aws_cloudwatch_log_metric_filter" "auth_failures" {
  name           = "atlantis-auth-failures"
  log_group_name = "/aws/ecs/atlantis"

  pattern = "[time, request_id, level=ERROR, msg=\"*Unauthorized*\"]"

  metric_transformation {
    name      = "AuthFailureCount"
    namespace = "Atlantis"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "auth_failures" {
  alarm_name          = "atlantis-auth-failures-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "AuthFailureCount"
  namespace           = "Atlantis"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Atlantis authentication failures > 5 in 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

### 6. 보안 체크리스트

#### 배포 전 필수 확인사항
- [ ] **Secrets Manager**: GitHub token, webhook secret 저장 완료
- [ ] **IAM 역할**: 최소 권한 원칙 적용 (불필요한 `*` 권한 제거)
- [ ] **보안 그룹**: 인바운드 규칙이 필요한 IP만 허용
- [ ] **Private Subnet**: ECS Task가 Public Subnet에 배치되지 않음
- [ ] **Public IP**: ECS Task에 Public IP 비활성화됨
- [ ] **KMS 암호화**: Secrets, Logs, ECR 이미지 모두 암호화됨

#### 운영 중 주기적 점검
- [ ] **CloudTrail 로그**: 비정상적인 API 호출 확인 (매주)
- [ ] **IAM Access Analyzer**: 과도한 권한 검출 (매월)
- [ ] **VPC Flow Logs**: 비정상적인 네트워크 트래픽 확인 (매주)
- [ ] **Secrets Rotation**: GitHub token 주기적 교체 (분기별)
- [ ] **Container 취약점**: ECR 이미지 스캔 결과 확인 (매주)
- [ ] **보안 그룹 규칙**: 불필요한 규칙 제거 (매월)

#### 보안 사고 대응 준비
- [ ] **Runbook**: 보안 사고 대응 절차 문서화
- [ ] **연락처**: 보안팀 및 담당자 연락처 명시
- [ ] **Rollback 계획**: Task Definition 이전 버전 즉시 롤백 가능
- [ ] **격리 절차**: 침해 의심 시 Task 즉시 중지 절차 수립

## Troubleshooting

### 1. ECS Task가 시작되지 않는 경우

**증상**: ECS 서비스가 Task를 시작하지 못하고 계속 재시도

**확인 방법**:
```bash
# ECS 서비스 상태 확인
aws ecs describe-services \
  --cluster atlantis-prod \
  --services atlantis-prod \
  --region ap-northeast-2

# Task 실행 실패 이유 확인
aws ecs describe-tasks \
  --cluster atlantis-prod \
  --tasks $(aws ecs list-tasks --cluster atlantis-prod --service-name atlantis-prod --region ap-northeast-2 --query 'taskArns[0]' --output text) \
  --region ap-northeast-2
```

**일반적인 원인 및 해결 방법**:

1. **ECR 이미지 풀링 실패**:
   - Task Execution Role에 ECR 권한이 있는지 확인
   - ECR KMS 키 복호화 권한 확인
   ```bash
   # ECR 이미지 존재 확인
   aws ecr describe-images --repository-name atlantis --region ap-northeast-2
   ```

2. **서브넷 구성 오류**:
   - Private 서브넷에 NAT Gateway가 있는지 확인
   - 서브넷 라우팅 테이블 확인
   ```bash
   aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=<subnet-id>"
   ```

3. **보안 그룹 문제**:
   - ECS Task 보안 그룹이 아웃바운드 트래픽을 허용하는지 확인
   - ECR, Secrets Manager, CloudWatch Logs 접근 가능한지 확인

### 2. ALB 헬스체크 실패

**증상**: Target Group에서 Unhealthy 상태

**확인 방법**:
```bash
# Target Group 헬스 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw atlantis_target_group_arn) \
  --region ap-northeast-2
```

**해결 방법**:

1. **헬스체크 경로 확인**:
   - Atlantis가 `/healthz` 엔드포인트를 제공하는지 확인
   - 컨테이너 로그에서 헬스체크 요청 확인
   ```bash
   # 로그 확인
   aws logs tail /aws/ecs/atlantis/application --follow --region ap-northeast-2
   ```

2. **보안 그룹 규칙 검증**:
   - ALB 보안 그룹 → ECS Task 보안 그룹 연결 확인
   - 포트 4141 인바운드 규칙 확인

3. **컨테이너 시작 대기 시간 증가**:
   - 헬스체크 시작 전 대기 시간(grace period) 조정 필요 시 `service.tf`에서 `health_check_grace_period_seconds` 수정

### 3. Atlantis GitHub 연결 문제

**증상**: Atlantis가 GitHub Webhook을 받지 못하거나 댓글을 달지 못함

**확인 방법**:
```bash
# Atlantis 로그에서 GitHub 관련 에러 확인
aws logs filter-pattern '{ $.level = "error" }' \
  --log-group-name /aws/ecs/atlantis/application \
  --region ap-northeast-2 \
  --start-time $(date -u -v-1H +%s)000
```

**해결 방법**:

1. **GitHub Token 확인**:
   - Secrets Manager에 GitHub Token이 올바르게 저장되어 있는지 확인
   - Token 권한: `repo`, `admin:repo_hook`

2. **Webhook URL 확인**:
   - ALB DNS 이름 확인
   ```bash
   terraform output atlantis_alb_dns_name
   ```
   - Route53 레코드가 ALB를 가리키는지 확인
   - GitHub Webhook 설정에서 URL이 `https://atlantis.set-of.com/events`인지 확인

3. **Webhook Secret 일치 확인**:
   - GitHub Webhook Secret과 Atlantis 환경 변수가 일치하는지 확인

### 4. Terraform Plan/Apply 권한 문제

**증상**: Atlantis가 Terraform 명령어 실행 시 권한 에러 발생

**확인 방법**:
```bash
# Task Role 정책 확인
aws iam get-role --role-name atlantis-prod-task-role --region ap-northeast-2
aws iam list-attached-role-policies --role-name atlantis-prod-task-role --region ap-northeast-2
```

**해결 방법**:

1. **S3 State 접근 권한**:
   - Task Role에 S3 버킷 접근 권한 추가
   - KMS 키 복호화 권한 확인

2. **DynamoDB Lock Table 권한**:
   - DynamoDB `terraform-lock` 테이블 접근 권한 확인

3. **AWS 리소스 생성 권한**:
   - 현재는 읽기 전용 권한만 부여됨 (`iam.tf` 참조)
   - Plan 작업만 가능하며, Apply는 제한됨
   - Apply 필요 시 `iam.tf`에서 추가 권한 부여 필요

### 5. 컨테이너 로그 확인

**실시간 로그 스트리밍**:
```bash
# CloudWatch Logs 실시간 확인
aws logs tail /aws/ecs/atlantis/application --follow --region ap-northeast-2

# 특정 시간 범위 로그 확인
aws logs tail /aws/ecs/atlantis/application \
  --since 1h \
  --region ap-northeast-2
```

**에러 로그 필터링**:
```bash
# ERROR 레벨 로그만 확인
aws logs filter-pattern 'ERROR' \
  --log-group-name /aws/ecs/atlantis/application \
  --region ap-northeast-2 \
  --start-time $(date -u -v-1H +%s)000
```

### 6. ECS 서비스 재시작

Task가 정상적으로 작동하지 않을 때:

```bash
# 새로운 배포 강제 실행 (새 Task 시작)
aws ecs update-service \
  --cluster atlantis-prod \
  --service atlantis-prod \
  --force-new-deployment \
  --region ap-northeast-2

# 서비스 상태 모니터링
aws ecs describe-services \
  --cluster atlantis-prod \
  --services atlantis-prod \
  --region ap-northeast-2 \
  --query 'services[0].{RunningCount:runningCount,DesiredCount:desiredCount,Status:status}'
```

### 7. 네트워크 연결 문제

**VPC 엔드포인트 확인**:
```bash
# ECR, Secrets Manager, Logs VPC 엔드포인트 확인
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --region ap-northeast-2 \
  --query 'VpcEndpoints[*].{Service:ServiceName,State:State}'
```

**NAT Gateway 상태 확인**:
```bash
# NAT Gateway 상태 확인
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --region ap-northeast-2 \
  --query 'NatGateways[*].{NatGatewayId:NatGatewayId,State:State,SubnetId:SubnetId}'
```

### 8. 일반적인 체크리스트

배포 후 확인 사항:

- [ ] ECS 서비스가 정상적으로 실행 중 (`ACTIVE` 상태)
- [ ] Running Task 개수 = Desired Task 개수
- [ ] Target Group 헬스체크 `Healthy` 상태
- [ ] ALB DNS 이름으로 접속 가능
- [ ] Route53 레코드가 ALB를 가리킴
- [ ] HTTPS 인증서 정상 작동 (브라우저 경고 없음)
- [ ] GitHub Webhook 정상 수신 (Atlantis UI에서 확인)
- [ ] CloudWatch Logs에 에러 로그 없음

## 관련 이슈

- Jira: [IN-12](https://ryuqqq.atlassian.net/browse/IN-12) - Application Load Balancer 구성
- Jira: [IN-11](https://ryuqqq.atlassian.net/browse/IN-11) - ECS 클러스터 및 Task Definition 생성
- Epic: [IN-1](https://ryuqqq.atlassian.net/browse/IN-1) - Phase 1: Atlantis 서버 ECS 배포

---

**Last Updated**: 2025-01-22
**Maintained By**: Platform Team

