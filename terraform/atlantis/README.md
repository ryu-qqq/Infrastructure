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

## 변수

주요 변수는 `variables.tf`에 정의되어 있습니다:

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `environment` | 환경 이름 | `prod` |
| `aws_region` | AWS 리전 | `ap-northeast-2` |
| `atlantis_version` | Atlantis 버전 | `latest` |
| `atlantis_cpu` | Task CPU | `512` |
| `atlantis_memory` | Task Memory (MiB) | `1024` |
| `atlantis_container_port` | 컨테이너 포트 | `4141` |

## 출력값

배포 후 다음 값들이 출력됩니다:
- ECR 저장소 URL 및 ARN
- ECS 클러스터 정보
- IAM 역할 ARN
- Task Definition ARN 및 버전
- CloudWatch Log Group 이름

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

추가로 필요한 작업 (Phase 1 완료를 위해):
- [ ] VPC 및 서브넷 구성
- [ ] Application Load Balancer 설정
- [ ] ACM 인증서 발급
- [ ] ECS 서비스 정의
- [ ] 보안 그룹 구성
- [ ] Route53 DNS 설정

## 관련 이슈

- Jira: [IN-11](https://ryuqqq.atlassian.net/browse/IN-11) - ECS 클러스터 및 Task Definition 생성
- Epic: [IN-1](https://ryuqqq.atlassian.net/browse/IN-1) - Phase 1: Atlantis 서버 ECS 배포
