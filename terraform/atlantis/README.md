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

## 관련 이슈

- Jira: [IN-12](https://ryuqqq.atlassian.net/browse/IN-12) - Application Load Balancer 구성
- Jira: [IN-11](https://ryuqqq.atlassian.net/browse/IN-11) - ECS 클러스터 및 Task Definition 생성
- Epic: [IN-1](https://ryuqqq.atlassian.net/browse/IN-1) - Phase 1: Atlantis 서버 ECS 배포
