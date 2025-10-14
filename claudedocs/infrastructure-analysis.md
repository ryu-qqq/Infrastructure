# 기존 인프라 분석 결과

## Terraform 구조

### 디렉토리 구성
```
terraform/
├── atlantis/           # Atlantis ECS 서비스
├── atlantis-iam/       # Atlantis IAM 권한
├── bootstrap/          # 초기 설정
├── cloudtrail/         # 감사 로깅
├── kms/                # 암호화 키 관리
├── logging/            # 중앙 로깅 시스템 (IN-116)
├── modules/            # 재사용 가능한 모듈
├── network/            # VPC 및 네트워크
└── secrets/            # Secrets Manager
```

### Remote State 구조
- **Backend**: S3 + DynamoDB lock
- **State 파일 위치**: `s3://terraform-state/<module>/terraform.tfstate`
- **예시**: `kms/terraform.tfstate`, `network/terraform.tfstate`

## 네트워크 인프라

### VPC 구성
- **VPC ID**: `aws_vpc.main` (imported existing VPC)
- **CIDR**: `var.vpc_cidr` (환경별로 다름)
- **DNS**: Hostnames 및 Support 활성화
- **주요 특징**:
  - Public/Private 서브넷 분리
  - NAT Gateway (프라이빗 서브넷 인터넷 연결)
  - Internet Gateway (퍼블릭 서브넷 인터넷 연결)
  - Transit Gateway 옵션 (필요시 활성화)

### 서브넷
- **Public Subnets**: `aws_subnet.public[*]` - ALB 배포용
- **Private Subnets**: `aws_subnet.private[*]` - ECS 태스크, RDS 배포용

### 보안 그룹
- ALB Security Group (atlantis/alb.tf)
- ECS Service Security Group (atlantis/service.tf)
- VPC Endpoints Security Group (atlantis/vpc-endpoints.tf)

## ECS 인프라

### Atlantis ECS 클러스터
- **클러스터 이름**: `atlantis-${var.environment}`
- **Container Insights**: 활성화 ✅
- **Capacity Providers**: FARGATE, FARGATE_SPOT
- **CPU/Memory**: 512 CPU units / 1024 MiB (기본값)

### ECS 서비스 패턴
- Task Definition에 컨테이너 정의
- ALB 연결 (Target Group)
- Service Discovery (옵션)
- Auto Scaling (옵션)

## 로깅 인프라 (IN-116 작업)

### CloudWatch Log Groups
현재 구성된 로그 그룹:
- `/aws/ecs/atlantis/application` (14일 보존)
- `/aws/ecs/atlantis/errors` (90일 보존)
- `/aws/lambda/secrets-manager-rotation` (14일 보존)

### KMS 암호화
- 모든 CloudWatch Logs는 KMS로 암호화
- KMS Key: `data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn`

### 메트릭 필터
- Error rate 메트릭 자동 생성 옵션 있음
- Namespace: `CustomLogs/Atlantis`

## 태그 표준

### Required Tags (Governance)
```hcl
locals {
  required_tags = {
    Owner       = var.owner              # platform-team
    CostCenter  = var.cost_center        # engineering
    Environment = var.environment        # prod/dev/staging
    Lifecycle   = var.resource_lifecycle # permanent
    DataClass   = var.data_class         # confidential
    Service     = var.service            # service name
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }
}
```

## AMP/AMG 통합 고려사항

### 1. ECS Container Insights
- **현재 상태**: 활성화됨
- **제공 메트릭**:
  - CPU/Memory 사용률
  - 네트워크 I/O
  - Task 개수
- **AMP 연동 방안**:
  - ADOT Collector로 Container Insights 메트릭 수집
  - CloudWatch → AMP 스트리밍

### 2. VPC Endpoints 활용
- **기존 설정**: atlantis/vpc-endpoints.tf에 VPC 엔드포인트 정의
- **AMP/AMG 추가 필요**:
  - `com.amazonaws.region.aps-workspaces` (AMP)
  - `com.amazonaws.region.grafana` (AMG, 필요시)

### 3. IAM 역할 통합
- **기존 패턴**: atlantis-iam/ 디렉토리에 분리된 IAM 리소스
- **AMP/AMG용**: 별도 디렉토리 생성 권장 (`monitoring-iam/`)

### 4. KMS 키 재사용
- **현재 KMS 키**:
  - CloudWatch Logs용 KMS 키 존재
- **AMP 암호화**:
  - 기존 키 재사용 또는 새로운 키 생성 (분리 권장)

### 5. 보안 그룹 고려
- ECS 태스크 → AMP endpoint: 443 포트 허용
- Grafana → AMP: VPC 피어링 또는 인터넷 경유

## 모니터링 대상 리소스

### 1. ECS Services
- **현재 서비스**: Atlantis
- **미래 서비스**: API Server, Worker 등 (주석 처리됨)
- **메트릭 소스**: Container Insights + ADOT Collector

### 2. RDS (향후 추가)
- **로그 그룹 패턴**: `/aws/rds/instance/<instance-id>/...`
- **메트릭**: Enhanced Monitoring, Performance Insights

### 3. ALB
- **현재**: Atlantis ALB
- **메트릭**: CloudWatch ALB 메트릭 (자동 수집)

## 권장 디렉토리 구조

```
terraform/
├── monitoring/
│   ├── amp.tf              # AMP Workspace
│   ├── amg.tf              # AMG Workspace
│   ├── iam.tf              # IAM 역할 및 정책
│   ├── adot-config.tf      # ADOT Collector 설정
│   ├── dashboards/         # Grafana 대시보드 JSON
│   │   ├── overview.json
│   │   ├── ecs.json
│   │   ├── rds.json
│   │   └── alb.json
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   └── terraform.tfvars
```

## 다음 단계 준비사항

### 필요한 정보
1. AWS Region: `ap-northeast-2` (확인됨)
2. Environment: `prod` (기본값, 확인 필요)
3. VPC ID: Terraform output에서 참조
4. Private Subnet IDs: ADOT Collector 배포용
5. KMS Key ARN: 암호화용

### Remote State Dependencies
```hcl
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "network/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "kms" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "kms/terraform.tfstate"
    region = var.aws_region
  }
}
```

## 통합 포인트

### Atlantis ECS Task에 ADOT 추가
1. `atlantis/task-definition.tf` 수정
2. ADOT Collector 사이드카 컨테이너 추가
3. IAM 역할에 AMP write 권한 부여
4. 환경 변수로 AMP endpoint 설정

### CloudWatch Logs 활용
1. 기존 로그 그룹에 메트릭 필터 추가
2. 에러율, 응답 시간 등 애플리케이션 메트릭 추출
3. AMP로 메트릭 스트리밍

## 참고사항

- **Container Insights 활성화**: 이미 활성화되어 있어 추가 비용 발생 중
- **ECS Exec 활성화**: 디버깅 용이성을 위해 고려
- **Service Connect**: 마이크로서비스 간 통신 메트릭 수집에 유용
