# Atlantis Basic Example

이 예제는 AWS ECS Fargate에서 Atlantis를 배포하는 기본 구성을 보여줍니다.

## 개요

이 예제에서 배포되는 리소스:

- **ECS Cluster**: Fargate 기반 Atlantis 실행 환경
- **ALB**: HTTPS를 통한 외부 접근
- **Security Groups**: ALB 및 ECS Task 보안 그룹
- **CloudWatch Logs**: Atlantis 로그 수집
- **ECS Service**: Atlantis 컨테이너 실행

## 사전 요구사항

### 1. 기존 인프라

다음 리소스가 이미 존재해야 합니다:

- **VPC**: Environment 태그가 설정된 VPC
- **Public Subnets**: Type=Public 태그가 있는 서브넷 (최소 2개, Multi-AZ)
- **Private Subnets**: Type=Private 태그가 있는 서브넷 (최소 2개, Multi-AZ)
- **ACM Certificate**: HTTPS를 위한 SSL 인증서

### 2. GitHub 설정

- GitHub Personal Access Token (repo, admin:repo_hook 권한 필요)
- GitHub Webhook Secret
- Atlantis를 사용할 Repository 정보

### 3. AWS Secrets Manager

GitHub 토큰과 Webhook Secret을 저장할 Secrets Manager 시크릿 생성:

```bash
# GitHub Token 저장
aws secretsmanager create-secret \
  --name atlantis/github-token \
  --secret-string "ghp_your_token_here" \
  --region ap-northeast-2

# Webhook Secret 저장
aws secretsmanager create-secret \
  --name atlantis/github-webhook-secret \
  --secret-string "your_webhook_secret_here" \
  --region ap-northeast-2
```

## 사용 방법

### 1. Variables 설정

`terraform.tfvars` 파일 생성:

```hcl
environment             = "dev"
aws_region              = "ap-northeast-2"
atlantis_version        = "v0.30.0"
github_repo_allowlist   = "github.com/yourorg/*"
acm_certificate_arn     = "arn:aws:acm:ap-northeast-2:123456789012:certificate/..."

# Required Tags
owner              = "platform-team"
cost_center        = "engineering"
resource_lifecycle = "temporary"
data_class         = "confidential"
service            = "atlantis"
```

### 2. Terraform 실행

```bash
# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply
```

### 3. Atlantis 접속 확인

배포 완료 후 ALB DNS Name으로 접속:

```bash
# ALB DNS Name 확인
terraform output alb_dns_name

# 헬스체크 확인
curl https://<alb-dns-name>/healthz
```

### 4. GitHub Webhook 설정

GitHub Repository Settings에서 Webhook 추가:

- **Payload URL**: `https://<alb-dns-name>/events`
- **Content type**: `application/json`
- **Secret**: Secrets Manager에 저장한 webhook secret
- **Events**:
  - Pull request reviews
  - Pushes
  - Issue comments
  - Pull requests

## 주요 구성 설정

### ECS Task 리소스

- **CPU**: 512 (0.5 vCPU)
- **Memory**: 1024 MB (1 GB)
- **Platform**: Fargate

### ALB 설정

- **Type**: Application Load Balancer
- **Scheme**: Internet-facing
- **Protocol**: HTTPS (Port 443)
- **SSL Policy**: ELBSecurityPolicy-TLS-1-2-2017-01

### 헬스체크

- **Path**: `/healthz`
- **Interval**: 30초
- **Timeout**: 5초
- **Healthy Threshold**: 2
- **Unhealthy Threshold**: 3

## 비용 예상

이 기본 구성의 월 예상 비용 (서울 리전 기준):

| 리소스 | 사양 | 월 비용 (USD) |
|--------|------|---------------|
| ECS Fargate | 0.5 vCPU, 1GB RAM | ~$15 |
| ALB | 1개 | ~$20 |
| NAT Gateway | 2개 (Multi-AZ) | ~$65 |
| CloudWatch Logs | 7일 보관 | ~$5 |
| **총 예상** | | **~$105** |

> **참고**: 실제 비용은 트래픽량, 로그량, 데이터 전송량에 따라 달라질 수 있습니다.

## 보안 고려사항

### 1. Network 격리

- ECS Task는 Private 서브넷에서 실행
- 인터넷 접근은 NAT Gateway를 통해서만 가능
- ALB만 Public 서브넷에 배치

### 2. Security Group 설정

- ALB: HTTPS(443) 포트만 인터넷에서 접근 허용
- ECS Task: ALB로부터의 4141 포트만 허용

### 3. Secrets 관리

- GitHub Token 및 Webhook Secret은 Secrets Manager에 저장
- ECS Task에서 환경 변수로 주입 (평문 노출 방지)

### 4. IAM 최소 권한

이 기본 예제에서는 IAM 역할 설정이 포함되어 있지 않습니다. 프로덕션 환경에서는:

- ECS Task Execution Role: ECR pull, Secrets Manager 읽기 권한
- ECS Task Role: Terraform 실행에 필요한 최소 권한

## 프로덕션 배포 시 추가 고려사항

이 기본 예제를 프로덕션에 배포하기 전 다음 사항을 추가 구성하세요:

### 1. 고가용성

- `desired_count = 2` 이상으로 설정
- Auto Scaling 정책 추가

### 2. IAM 역할 구성

```hcl
# ECS Task Execution Role
# - ecr:GetAuthorizationToken
# - ecr:BatchCheckLayerAvailability
# - ecr:GetDownloadUrlForLayer
# - ecr:BatchGetImage
# - secretsmanager:GetSecretValue
# - logs:CreateLogStream
# - logs:PutLogEvents

# ECS Task Role
# - Terraform 실행에 필요한 최소 권한
# - S3 state backend 접근 권한
# - DynamoDB lock table 접근 권한
```

### 3. 모니터링 및 알람

- CloudWatch Alarms 설정
- ECS Service CPU/Memory 사용률 모니터링
- ALB 5xx 에러율 모니터링

### 4. 로깅

- CloudWatch Logs 보관 기간 연장 (30일 이상)
- S3로 로그 아카이빙 설정

### 5. 백업

- Terraform State 백업 (S3 버전 관리 활성화)
- atlantis.yaml 설정 버전 관리

## Outputs

배포 후 다음 정보를 확인할 수 있습니다:

```bash
# ALB DNS Name
terraform output alb_dns_name

# ECS Cluster Name
terraform output ecs_cluster_name

# ECS Service Name
terraform output ecs_service_name

# CloudWatch Log Group
terraform output log_group_name
```

## 정리 (Clean Up)

리소스 삭제:

```bash
terraform destroy
```

**주의사항**:
- ECS Service를 먼저 종료한 후 다른 리소스를 삭제하세요
- ALB가 완전히 삭제되기까지 수 분이 소요될 수 있습니다

## 참고 자료

- [Atlantis 공식 문서](https://www.runatlantis.io/)
- [AWS ECS Fargate 문서](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Atlantis 전체 패키지 문서](../../README.md)

## 문의

- **문의 채널**: Slack #infrastructure
