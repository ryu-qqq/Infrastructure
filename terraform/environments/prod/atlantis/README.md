# Atlantis Stack - Production Environment

## 개요

Atlantis는 Pull Request 기반의 Terraform 자동화 서버입니다. 이 스택은 AWS ECS Fargate에서 실행되며, GitHub App을 통해 PR에 자동으로 `terraform plan`과 `terraform apply`를 실행합니다.

**주요 기능**:
- GitHub PR에서 자동 Terraform plan/apply 실행
- Multi-repo 지원 (ryu-qqq 조직 전체)
- EFS를 통한 Atlantis 데이터 영구 저장
- ALB를 통한 GitHub Webhook 수신
- GitHub App 인증을 통한 보안 강화

## 아키텍처

### 전체 구성도

```
GitHub PR
    ↓ (Webhook)
Application Load Balancer (Public Subnet)
    ↓
ECS Service (Private Subnet)
    ├─ Atlantis Container (Fargate)
    │   ├─ GitHub App 인증
    │   ├─ Terraform 실행
    │   └─ EFS 마운트 (/home/atlantis/.atlantis)
    │
    └─ 접근 리소스
        ├─ ECR (Docker 이미지)
        ├─ EFS (영구 데이터 저장)
        ├─ S3 (Terraform State)
        ├─ DynamoDB (State Lock)
        └─ Secrets Manager (GitHub 인증 정보)
```

### 네트워크 구성

- **ALB**: Public Subnet (인터넷 접근 가능)
- **ECS Tasks**: Private Subnet (NAT Gateway를 통한 아웃바운드만 허용)
- **EFS Mount Targets**: Private Subnet (Multi-AZ 고가용성)

### 보안 구성

1. **Security Groups**:
   - ALB SG: 특정 CIDR에서만 HTTPS(443) 허용
   - ECS Tasks SG: ALB에서만 4141 포트 접근 허용
   - EFS SG: ECS Tasks에서만 NFS(2049) 접근 허용

2. **IAM Roles**:
   - Task Execution Role: ECR 이미지 pull, Secrets 읽기, 로그 기록
   - Task Role: Terraform 작업 수행, S3/DynamoDB 접근, AWS 리소스 관리

3. **Encryption**:
   - ECR: KMS 암호화
   - EFS: AWS 관리형 키 암호화
   - Secrets Manager: 자동 암호화
   - CloudWatch Logs: AWS 관리형 키 암호화

## 사용된 Modules

### 1. **ECR Module** (`../../modules/ecr`)
- **파일**: `ecr.tf`
- **역할**: Atlantis Docker 이미지 저장소 관리
- **주요 기능**:
  - KMS 암호화 지원
  - 이미지 스캔 활성화
  - 라이프사이클 정책 (최근 10개 버전 유지, 7일 후 untagged 이미지 삭제)
  - Repository 정책 (ECS Task 접근 권한)

### 2. **Security Group Module** (`../../modules/security-group`)
- **파일**: `alb.tf`, `efs.tf`
- **역할**: ALB, ECS Tasks, EFS용 보안 그룹 관리
- **주요 기능**:
  - ALB 보안 그룹: HTTP/HTTPS 인바운드 규칙
  - ECS Tasks 보안 그룹: ALB로부터 컨테이너 포트 접근
  - EFS 보안 그룹: ECS Tasks로부터 NFS 접근

### 3. **ALB Module** (`../../modules/alb`)
- **파일**: `alb.tf`
- **역할**: Application Load Balancer 및 Target Group 관리
- **주요 기능**:
  - HTTP → HTTPS 리다이렉트
  - TLS 1.3 지원 (`ELBSecurityPolicy-TLS13-1-2-2021-06`)
  - ACM 인증서 통합
  - 헬스체크 구성 (`/healthz`)
  - IP 타겟 타입 (Fargate 호환)

### 4. **IAM Role Policy Module** (`../../modules/iam-role-policy`)
- **파일**: `iam.tf`
- **역할**: ECS Task Execution Role 및 Task Role 관리
- **주요 기능**:
  - AWS 관리형 정책 연결 (`AmazonECSTaskExecutionRolePolicy`)
  - Inline 정책 관리 (KMS, Secrets, Terraform 작업)
  - EFS 접근 권한 (Access Point 기반)

### 5. **CloudWatch Log Group Module** (`../../modules/cloudwatch-log-group`)
- **파일**: `logs.tf`
- **역할**: ECS 컨테이너 로그 저장
- **주요 기능**:
  - 7일 로그 보존 기간
  - AWS 관리형 키 암호화
  - 태그 자동 관리

## Raw 리소스 (모듈 미사용)

다음 리소스들은 복잡한 구성 또는 모듈 미지원으로 인해 직접 관리됩니다:

### 1. **ECS Cluster** (`ecs.tf`)
- Fargate 및 Fargate Spot 용량 제공자 구성
- Container Insights 활성화

### 2. **ECS Task Definition** (`task-definition.tf`)
- **이유**: EFS 볼륨 마운트, Secrets Manager 통합 등 복잡한 구성
- **주요 구성**:
  - CPU: 2048, Memory: 4096
  - EFS 볼륨 마운트 (`/home/atlantis/.atlantis`)
  - GitHub App 인증 정보 (Secrets Manager)
  - 헬스체크 (`/healthz`)
  - 환경 변수 (URL, Repo Allowlist 등)

### 3. **ECS Service** (`service.tf`)
- **이유**: 특수한 배포 전략 (Blue/Green) 필요
- **주요 구성**:
  - Desired Count: 1
  - Deployment Strategy: 100% max, 0% min (EFS 동시 접근 방지)
  - Circuit Breaker (자동 롤백)
  - ALB Target Group 연결

### 4. **EFS File System** (`efs.tf`)
- **이유**: EFS 모듈 미제공
- **주요 구성**:
  - 암호화: AWS 관리형 키 (TODO: KMS 전환 예정)
  - Performance Mode: generalPurpose
  - Throughput Mode: bursting
  - Lifecycle Policy: 30일 후 IA 전환
  - Mount Targets: Multi-AZ (Private Subnet별 1개)
  - Access Point: POSIX 사용자 (UID/GID: 100)

### 5. **KMS Keys** (`kms.tf`)
- ECR 암호화용 KMS 키
- EFS 암호화용 KMS 키 (TODO: 적용 예정)
- 자동 키 회전 활성화

### 6. **Secrets Manager** (`secrets.tf`)
- GitHub App 인증 정보 (App ID, Installation ID, Private Key)
- Webhook Secret
- JSON 구조로 여러 값 저장

### 7. **VPC Endpoints** (`vpc-endpoints.tf`)
- ECR API, ECR DKR, S3, Secrets Manager 엔드포인트
- Private Subnet에서 AWS 서비스 접근 (비용 절감 + 보안 강화)

## 사용 방법

### 1. 사전 요구사항

- AWS CLI 구성 완료
- Terraform >= 1.5.0
- VPC 및 Subnet 준비 (Public/Private)
- ACM 인증서 발급 완료
- GitHub App 생성 및 설정

### 2. 변수 설정

`terraform.tfvars` 파일 생성:

```hcl
# Network
vpc_id              = "vpc-xxxxxxxxx"
public_subnet_ids   = ["subnet-xxx", "subnet-yyy"]
private_subnet_ids  = ["subnet-zzz", "subnet-aaa"]

# Security
allowed_cidr_blocks = ["1.2.3.4/32"]  # 접근 허용 IP

# Certificate
acm_certificate_arn = "arn:aws:acm:ap-northeast-2:ACCOUNT_ID:certificate/xxx"

# Atlantis Configuration
atlantis_url            = "https://atlantis.example.com"
atlantis_repo_allowlist = "github.com/ryu-qqq/*"

# GitHub App (Secrets Manager에서 관리되므로 비워둠)
# github_app_id = ""
# github_app_installation_id = ""
# github_app_private_key = ""
# github_webhook_secret = ""
```

### 3. Secrets Manager 설정

GitHub App 인증 정보를 수동으로 Secrets Manager에 저장:

```bash
# GitHub App Secret 생성
aws secretsmanager create-secret \
  --name prod-atlantis-github-app \
  --description "Atlantis GitHub App credentials" \
  --secret-string '{
    "app_id": "123456",
    "installation_id": "12345678",
    "private_key": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
  }' \
  --region ap-northeast-2

# Webhook Secret 생성
aws secretsmanager create-secret \
  --name prod-atlantis-webhook-secret \
  --description "Atlantis GitHub Webhook secret" \
  --secret-string '{
    "webhook_secret": "your-random-webhook-secret"
  }' \
  --region ap-northeast-2
```

### 4. Terraform 실행

```bash
# 초기화
cd /path/to/terraform/environments/prod/atlantis
terraform init

# 포맷 및 검증
terraform fmt
terraform validate

# 계획 확인
terraform plan

# 배포
terraform apply
```

### 5. GitHub Webhook 설정

Terraform 배포 후 출력된 ALB DNS 이름으로 GitHub Webhook 설정:

1. GitHub Organization 설정 → Apps → Your App
2. Webhook URL: `https://atlantis.example.com/events`
3. Webhook Secret: Secrets Manager의 `webhook_secret` 값
4. 권한: Repository (Read & Write), Pull Requests (Read & Write)

### 6. Route53 설정 (선택)

ALB에 도메인 연결:

```hcl
resource "aws_route53_record" "atlantis" {
  zone_id = "Z1234567890ABC"
  name    = "atlantis.example.com"
  type    = "A"

  alias {
    name                   = module.atlantis_alb.alb_dns_name
    zone_id                = module.atlantis_alb.alb_zone_id
    evaluate_target_health = true
  }
}
```

## 주요 출력값

배포 후 다음 값들이 출력됩니다:

### ECR
- `atlantis_ecr_repository_url`: ECR 저장소 URL (Docker 이미지 push/pull)
- `atlantis_ecr_repository_arn`: ECR 저장소 ARN

### ECS
- `atlantis_ecs_cluster_id`: ECS 클러스터 ID
- `atlantis_ecs_cluster_name`: ECS 클러스터 이름
- `atlantis_ecs_service_name`: ECS 서비스 이름
- `atlantis_task_definition_arn`: Task Definition ARN
- `atlantis_task_definition_revision`: Task Definition 버전

### ALB
- `atlantis_alb_dns_name`: ALB DNS 이름 (Route53 설정에 사용)
- `atlantis_alb_zone_id`: ALB Zone ID (Route53 Alias 레코드)
- `atlantis_target_group_arn`: Target Group ARN

### Security Groups
- `atlantis_alb_security_group_id`: ALB 보안 그룹 ID
- `atlantis_ecs_tasks_security_group_id`: ECS Tasks 보안 그룹 ID

### IAM
- `atlantis_ecs_task_execution_role_arn`: Task Execution Role ARN
- `atlantis_ecs_task_role_arn`: Task Role ARN

### EFS
- `atlantis_efs_id`: EFS 파일 시스템 ID
- `atlantis_efs_dns_name`: EFS DNS 이름
- `atlantis_efs_access_point_id`: EFS Access Point ID

### Logs
- `atlantis_cloudwatch_log_group_name`: CloudWatch Log Group 이름
- `atlantis_cloudwatch_log_group_arn`: CloudWatch Log Group ARN

## 주의사항 및 제약

### 1. ECS 배포 전략

**현재 구성**: Blue/Green 배포 (0% min, 100% max)

- **이유**: EFS는 동시에 여러 Task가 같은 디렉터리를 쓰면 파일 잠금 문제 발생
- **결과**: 배포 시 기존 Task가 완전히 종료된 후 새 Task 시작
- **다운타임**: ~30초 (헬스체크 대기 시간 포함)

**대안**: Redis 기반 잠금으로 전환하면 무중단 배포 가능 (TODO)

### 2. EFS 암호화

**현재**: AWS 관리형 키 사용
**계획**: KMS 고객 관리형 키로 전환 예정

`efs.tf`의 TODO 주석 참고:
```hcl
# TODO: Re-enable KMS encryption after EFS is created successfully
# kms_key_id = aws_kms_key.efs.arn
```

### 3. Secrets 관리

- **GitHub App 인증 정보**: Terraform 외부에서 수동으로 Secrets Manager에 저장 필요
- **보안**: Terraform state에 민감 정보가 저장되지 않도록 함
- **순환**: GitHub App Private Key는 주기적 교체 권장 (분기별)

### 4. IAM 권한

**Task Role 권한**: Terraform plan/apply에 필요한 AWS 리소스 권한 부여

현재 부여된 권한:
- S3, DynamoDB (State 관리)
- ECS, ECR (컨테이너 관리)
- EC2, ELB (네트워크 리소스)
- IAM (제한적: `fileflow-*`, `atlantis-*` 역할만)
- CloudWatch Logs, Secrets Manager

**주의**: 과도한 권한 부여 시 보안 위험 → 필요한 리소스만 접근 가능하도록 ARN 제한

### 5. 비용 최적화

- **ECS Fargate**: 실행 시간에 따라 과금 (vCPU, Memory)
- **EFS**: 저장 용량 + I/O 요청 수에 따라 과금
  - Lifecycle Policy: 30일 후 IA 전환으로 비용 절감
- **ALB**: 시간당 과금 + LCU (처리량)
- **VPC Endpoints**: 시간당 과금 + 데이터 전송량

**절감 방법**:
- VPC Endpoint 사용 (NAT Gateway 비용 절감)
- EFS IA 전환 활용
- Fargate Spot 사용 검토 (비용 최대 70% 절감, 단 중단 가능성)

### 6. 고가용성

**현재 구성**:
- ECS Desired Count: 1 (단일 Task)
- ALB: Multi-AZ (Public Subnet 2개)
- EFS: Multi-AZ (Mount Target 2개)

**제한**:
- ECS Task 1개만 실행 → Task 재시작 시 다운타임 발생
- 고가용성 필요 시 Redis 잠금 메커니즘 도입 후 Desired Count 증가 권장

### 7. 로그 보존

- **CloudWatch Logs**: 7일 보존
- **장기 보관 필요 시**: S3 Export 또는 Kinesis Firehose 통합 필요

### 8. 네트워크 접근

**ALB 접근 제한**:
- `allowed_cidr_blocks` 변수로 접근 IP 제한
- 보안 강화를 위해 VPN/Office IP만 허용 권장

**ECS Tasks**:
- Private Subnet 배치 (Public IP 없음)
- NAT Gateway를 통한 아웃바운드만 허용
- VPC Endpoint로 AWS 서비스 접근

### 9. GitHub App vs Personal Access Token

**현재**: GitHub App 사용 (권장)

장점:
- 조직 수준 권한 관리
- Rate Limit 증가 (시간당 15,000 요청)
- 보안 감사 용이
- Token 만료 없음 (Private Key 기반)

단점:
- 설정이 복잡함 (App 생성, Installation)

## 문제 해결

### ECS Task가 시작되지 않는 경우

```bash
# ECS 서비스 상태 확인
aws ecs describe-services \
  --cluster atlantis-prod \
  --services atlantis-prod \
  --region ap-northeast-2

# Task 실행 실패 이유 확인
aws ecs list-tasks \
  --cluster atlantis-prod \
  --service-name atlantis-prod \
  --region ap-northeast-2
```

일반적인 원인:
1. ECR 이미지가 없음 → Docker 이미지 빌드 및 push 필요
2. Secrets Manager 값 없음 → GitHub App 인증 정보 설정 필요
3. EFS Mount 실패 → Security Group 확인 (NFS 2049 포트)

### ALB 헬스체크 실패

```bash
# Target Group 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw atlantis_target_group_arn) \
  --region ap-northeast-2
```

해결 방법:
- Atlantis 컨테이너가 `/healthz` 엔드포인트 제공하는지 확인
- Security Group에서 ALB → ECS Tasks 4141 포트 허용 확인

### GitHub Webhook이 도달하지 않는 경우

```bash
# CloudWatch Logs 확인
aws logs tail /ecs/atlantis-prod --follow --region ap-northeast-2
```

확인 사항:
1. Route53에서 도메인이 ALB를 가리키는지 확인
2. ACM 인증서가 도메인과 일치하는지 확인
3. GitHub Webhook URL이 `https://atlantis.example.com/events`인지 확인
4. Webhook Secret이 Secrets Manager 값과 일치하는지 확인

### EFS 접근 오류

```bash
# EFS Mount Target 상태 확인
aws efs describe-mount-targets \
  --file-system-id $(terraform output -raw atlantis_efs_id) \
  --region ap-northeast-2
```

확인 사항:
- EFS Security Group에서 ECS Tasks SG로부터 2049 포트 허용 확인
- EFS Access Point POSIX 사용자 (UID/GID: 100) 설정 확인

## 관련 문서

- [Atlantis 공식 문서](https://www.runatlantis.io/)
- [GitHub App 생성 가이드](https://www.runatlantis.io/docs/access-credentials.html#github-app)
- [ECS Fargate 모범 사례](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [EFS 파일 시스템 가이드](https://docs.aws.amazon.com/efs/latest/ug/whatisefs.html)

---

**Last Updated**: 2025-01-24
**Maintained By**: Platform Team
**Terraform Version**: >= 1.5.0
**AWS Provider Version**: >= 5.0
