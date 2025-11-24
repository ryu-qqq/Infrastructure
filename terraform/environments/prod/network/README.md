# Production Network Infrastructure

**버전**: 1.0.0
**환경**: Production
**리전**: ap-northeast-2 (Seoul)

> **중요**: 이 스택은 모듈을 사용하지 않고 raw Terraform 리소스로 구성되었습니다.
> 기존 AWS VPC를 import하여 Terraform으로 관리합니다.

---

## 📋 목차

- [개요](#개요)
- [아키텍처](#아키텍처)
- [네트워크 구성](#네트워크-구성)
- [리소스 목록](#리소스-목록)
- [변수 설정](#변수-설정)
- [출력값](#출력값)
- [배포 방법](#배포-방법)
- [운영 가이드](#운영-가이드)
- [문제 해결](#문제-해결)

---

## 개요

Production 환경의 네트워크 인프라를 관리하는 Terraform 스택입니다.

### 주요 특징

- **Multi-AZ 고가용성**: 2개의 가용 영역(ap-northeast-2a, ap-northeast-2b)에 분산 배치
- **Public/Private 서브넷 분리**: 보안을 위한 명확한 네트워크 격리
- **Transit Gateway 지원**: 멀티 VPC 통신을 위한 중앙 집중식 네트워크 허브 (선택 가능)
- **SSM Parameter 통합**: 다른 스택에서 네트워크 정보를 쉽게 참조 가능
- **기존 인프라 관리**: AWS Console에서 생성된 기존 VPC를 Terraform으로 import하여 관리

### 사용 모듈

- **없음** (모든 리소스가 raw Terraform 리소스)

---

## 아키텍처

### 네트워크 토폴로지

```
┌─────────────────────────────────────────────────────────────────────┐
│                     VPC (10.0.0.0/16)                                │
│                                                                       │
│  ┌────────────────────────────┐  ┌────────────────────────────┐     │
│  │   ap-northeast-2a          │  │   ap-northeast-2b          │     │
│  │                            │  │                            │     │
│  │  ┌──────────────────────┐  │  │  ┌──────────────────────┐  │     │
│  │  │ Public Subnet        │  │  │  │ Public Subnet        │  │     │
│  │  │ 10.0.0.0/24          │  │  │  │ 10.0.1.0/24          │  │     │
│  │  │                      │  │  │  │                      │  │     │
│  │  │ - NAT Gateway        │  │  │  │                      │  │     │
│  │  │ - Bastion Host       │  │  │  │ - Load Balancers     │  │     │
│  │  └──────────────────────┘  │  │  └──────────────────────┘  │     │
│  │                            │  │                            │     │
│  │  ┌──────────────────────┐  │  │  ┌──────────────────────┐  │     │
│  │  │ Private Subnet       │  │  │  │ Private Subnet       │  │     │
│  │  │ 10.0.10.0/24         │  │  │  │ 10.0.11.0/24         │  │     │
│  │  │                      │  │  │  │                      │  │     │
│  │  │ - Application Servers│  │  │  │ - Application Servers│  │     │
│  │  │ - Databases          │  │  │  │ - Databases          │  │     │
│  │  └──────────────────────┘  │  │  └──────────────────────┘  │     │
│  │            │               │  │            │               │     │
│  └────────────┼───────────────┘  └────────────┼───────────────┘     │
│               │                               │                     │
│               └───────────────┬───────────────┘                     │
│                               │                                     │
│                      ┌────────▼────────┐                            │
│                      │ Transit Gateway │ (선택 가능)                 │
│                      └─────────────────┘                            │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
                               │
                               │ (향후 확장)
                               │
                      ┌────────▼────────┐
                      │  다른 VPC들      │
                      │  (dev, staging)  │
                      └─────────────────┘
```

### 라우팅 구조

#### Public 서브넷 라우팅
- **목적지**: `0.0.0.0/0` → **타겟**: Internet Gateway
- **목적지**: `10.0.0.0/16` → **타겟**: Local (VPC 내부)

#### Private 서브넷 라우팅
- **목적지**: `0.0.0.0/0` → **타겟**: NAT Gateway (ap-northeast-2a)
- **목적지**: `10.0.0.0/16` → **타겟**: Local (VPC 내부)
- **목적지**: `<다른 VPC CIDR>` → **타겟**: Transit Gateway (활성화 시)

---

## 네트워크 구성

### CIDR 할당

| 리소스 | CIDR | 설명 |
|--------|------|------|
| **VPC** | `10.0.0.0/16` | 전체 네트워크 범위 (65,536개 IP) |
| **Public Subnet 1** | `10.0.0.0/24` | ap-northeast-2a (256개 IP) |
| **Public Subnet 2** | `10.0.1.0/24` | ap-northeast-2b (256개 IP) |
| **Private Subnet 1** | `10.0.10.0/24` | ap-northeast-2a (256개 IP) |
| **Private Subnet 2** | `10.0.11.0/24` | ap-northeast-2b (256개 IP) |

### 가용 영역 (AZ)

- **Primary AZ**: `ap-northeast-2a`
- **Secondary AZ**: `ap-northeast-2b`

---

## 리소스 목록

### 1. VPC

**리소스**: `aws_vpc.main`

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
}
```

**특징**:
- DNS 호스트명 및 DNS 지원 활성화
- 기본 인스턴스 테넌시 사용

### 2. 서브넷 (Subnets)

#### Public Subnets

**리소스**: `aws_subnet.public[*]`

- 총 2개 (Multi-AZ)
- Internet Gateway를 통한 인터넷 접근
- 자동 Public IP 할당 활성화

#### Private Subnets

**리소스**: `aws_subnet.private[*]`

- 총 2개 (Multi-AZ)
- NAT Gateway를 통한 인터넷 접근
- Public IP 비활성화 (보안 강화)

### 3. Internet Gateway

**리소스**: `aws_internet_gateway.main`

Public 서브넷의 인터넷 연결을 담당합니다.

### 4. NAT Gateway

**리소스**: `aws_nat_gateway.main`

- **위치**: ap-northeast-2a의 Public Subnet
- **용도**: Private 서브넷의 아웃바운드 인터넷 트래픽 처리
- **Elastic IP**: 자동 할당 및 연결

**비용 고려사항**:
- 시간당 요금: ~$0.045/hour (~$32/month)
- 데이터 전송: $0.045/GB

### 5. Route Tables

#### Public Route Table

**리소스**: `aws_route_table.public`

```hcl
# 기본 라우트
0.0.0.0/0 → Internet Gateway
10.0.0.0/16 → local
```

#### Private Route Table

**리소스**: `aws_route_table.private`

```hcl
# 기본 라우트
0.0.0.0/0 → NAT Gateway
10.0.0.0/16 → local

# Transit Gateway 활성화 시 추가 라우트
<다른 VPC CIDR> → Transit Gateway
```

### 6. Transit Gateway (선택 사항)

**리소스**: `aws_ec2_transit_gateway.main[0]`

**활성화 조건**: `var.enable_transit_gateway = true`

**설정**:
- Amazon Side ASN: `64512`
- DNS 지원: 활성화
- VPN ECMP 지원: 활성화
- 자동 라우트 수락: 활성화

**VPC Attachment**:
- **리소스**: `aws_ec2_transit_gateway_vpc_attachment.main[0]`
- **연결 서브넷**: Private Subnets (보안 강화)
- **Public 서브넷**: 연결하지 않음

**사용 사례**:
- 다른 환경의 VPC 간 통신 (dev, staging, prod)
- 마이크로서비스 간 VPC 분리 및 통신
- Shared Services VPC 연결 (모니터링, 로깅)
- 온프레미스 네트워크와의 VPN/Direct Connect 연결

**비용**:
- 시간당 요금: ~$0.05/hour (~$36/month)
- 데이터 전송: ~$0.02/GB

---

## 변수 설정

### 필수 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `environment` | `string` | `prod` | 환경 이름 |
| `aws_region` | `string` | `ap-northeast-2` | AWS 리전 |

### 네트워크 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `vpc_cidr` | `string` | `10.0.0.0/16` | VPC CIDR 블록 |
| `availability_zones` | `list(string)` | `["ap-northeast-2a", "ap-northeast-2b"]` | 가용 영역 |
| `public_subnet_cidrs` | `list(string)` | `["10.0.0.0/24", "10.0.1.0/24"]` | Public 서브넷 CIDR |
| `private_subnet_cidrs` | `list(string)` | `["10.0.10.0/24", "10.0.11.0/24"]` | Private 서브넷 CIDR |

### Transit Gateway 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `enable_transit_gateway` | `bool` | `true` | Transit Gateway 활성화 여부 |
| `transit_gateway_asn` | `number` | `64512` | Amazon Side ASN |
| `transit_gateway_routes` | `list(string)` | `[]` | TGW로 라우팅할 CIDR 목록 |

**Transit Gateway 라우트 예시**:
```hcl
transit_gateway_routes = [
  "10.1.0.0/16",  # Dev VPC
  "10.2.0.0/16",  # Staging VPC
]
```

### 거버넌스 태그 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `service_name` | `string` | `network` | 서비스 이름 (Service 태그) |
| `team` | `string` | `platform-team` | 담당 팀 (Owner 태그) |
| `project` | `string` | `shared-infrastructure` | 프로젝트 이름 (Component 태그) |
| `cost_center` | `string` | `infrastructure` | 비용 센터 (CostCenter 태그) |
| `data_class` | `string` | `internal` | 데이터 분류 (DataClass 태그) |
| `lifecycle_stage` | `string` | `production` | 라이프사이클 단계 (Lifecycle 태그) |

---

## 출력값

### 네트워크 정보

| 출력명 | 설명 |
|--------|------|
| `vpc_id` | VPC ID |
| `vpc_cidr` | VPC CIDR 블록 |
| `public_subnet_ids` | Public 서브넷 ID 목록 |
| `private_subnet_ids` | Private 서브넷 ID 목록 |
| `nat_gateway_id` | NAT Gateway ID |
| `internet_gateway_id` | Internet Gateway ID |
| `public_route_table_id` | Public 라우트 테이블 ID |
| `private_route_table_id` | Private 라우트 테이블 ID |

### Transit Gateway 정보

| 출력명 | 설명 |
|--------|------|
| `transit_gateway_id` | Transit Gateway ID |
| `transit_gateway_arn` | Transit Gateway ARN |
| `transit_gateway_vpc_attachment_id` | VPC Attachment ID |
| `transit_gateway_route_table_id` | TGW 기본 라우팅 테이블 ID |

### SSM Parameter Store 출력

다른 스택에서 네트워크 정보를 참조할 수 있도록 SSM Parameter로 자동 저장됩니다.

| Parameter Name | 값 |
|----------------|-----|
| `/shared/network/vpc-id` | VPC ID |
| `/shared/network/public-subnet-ids` | Public 서브넷 ID (콤마 구분) |
| `/shared/network/private-subnet-ids` | Private 서브넷 ID (콤마 구분) |

**다른 스택에서 참조 예시**:
```hcl
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
}
```

---

## 배포 방법

### 1. 사전 준비

#### AWS Credentials 설정
```bash
export AWS_PROFILE=prod
export AWS_REGION=ap-northeast-2
```

#### Terraform 초기화
```bash
cd terraform/environments/prod/network
terraform init
```

### 2. 배포 전 검증

#### 코드 포맷팅
```bash
terraform fmt
```

#### 코드 검증
```bash
terraform validate
```

#### 변경 사항 미리보기
```bash
terraform plan
```

### 3. 배포 실행

#### 기본 배포 (Transit Gateway 활성화)
```bash
terraform apply
```

#### Transit Gateway 비활성화
```bash
terraform apply -var="enable_transit_gateway=false"
```

#### 특정 변수 파일 사용
```bash
terraform apply -var-file="prod.tfvars"
```

### 4. 배포 후 확인

#### VPC 확인
```bash
aws ec2 describe-vpcs \
  --vpc-ids $(terraform output -raw vpc_id) \
  --region ap-northeast-2
```

#### 서브넷 확인
```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --region ap-northeast-2
```

#### Transit Gateway 확인 (활성화 시)
```bash
aws ec2 describe-transit-gateways \
  --transit-gateway-ids $(terraform output -raw transit_gateway_id) \
  --region ap-northeast-2
```

#### SSM Parameter 확인
```bash
aws ssm get-parameters-by-path \
  --path /shared/network \
  --recursive \
  --region ap-northeast-2
```

---

## 운영 가이드

### Transit Gateway 운영

#### 새로운 VPC 추가

**1단계: 새 VPC 생성 및 Attachment**

새로운 환경 (예: dev) 에서 VPC를 생성하고 Transit Gateway에 연결:

```hcl
# terraform/environments/dev/network/main.tf

data "aws_ssm_parameter" "transit_gateway_id" {
  name = "/shared/network/transit-gateway-id"
}

resource "aws_ec2_transit_gateway_vpc_attachment" "dev" {
  transit_gateway_id = data.aws_ssm_parameter.transit_gateway_id.value
  vpc_id             = aws_vpc.dev.id
  subnet_ids         = aws_subnet.private[*].id

  tags = merge(
    local.common_tags,
    {
      Name = "dev-tgw-attachment"
    }
  )
}
```

**2단계: Production VPC에 라우트 추가**

```hcl
# terraform/environments/prod/network/terraform.tfvars

transit_gateway_routes = [
  "10.1.0.0/16",  # Dev VPC CIDR
]
```

```bash
cd terraform/environments/prod/network
terraform apply
```

**3단계: Dev VPC에 라우트 추가**

```hcl
# terraform/environments/dev/network/route-tables.tf

resource "aws_route" "to_prod" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "10.0.0.0/16"  # Prod VPC CIDR
  transit_gateway_id     = data.aws_ssm_parameter.transit_gateway_id.value
}
```

**4단계: 보안 그룹 규칙 추가**

Prod VPC의 보안 그룹에서 Dev VPC 트래픽 허용:

```hcl
# terraform/environments/prod/security/security-groups.tf

resource "aws_security_group_rule" "allow_from_dev" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["10.1.0.0/16"]  # Dev VPC CIDR
  security_group_id = aws_security_group.database.id
  description       = "Allow MySQL from Dev VPC"
}
```

#### Transit Gateway 비활성화

현재 단일 VPC 환경에서 비용 절감이 필요한 경우:

```bash
terraform apply -var="enable_transit_gateway=false"
```

**주의사항**:
- Transit Gateway를 삭제하면 모든 VPC Attachment도 함께 삭제됩니다
- 다른 VPC가 연결되어 있는 경우 먼저 해당 Attachment를 삭제해야 합니다

### NAT Gateway 운영

#### Multi-AZ NAT Gateway 추가 (고가용성)

현재 단일 NAT Gateway (ap-northeast-2a) 사용 중입니다. 고가용성이 필요한 경우:

```hcl
# nat-gateway.tf

resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-nat-${count.index + 1}"
    }
  )
}

# Private 라우트 테이블도 각 AZ별로 생성 필요
```

**비용 영향**:
- NAT Gateway 추가 시: +$32/month
- 고가용성 확보: 하나의 AZ 장애 시에도 서비스 지속

### 네트워크 모니터링

#### VPC Flow Logs 활성화

모든 네트워크 트래픽을 로깅하여 보안 및 성능 분석:

```hcl
# flow-logs.tf (새로 생성)

resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-vpc-flow-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.environment}"
  retention_in_days = 30
  kms_key_id        = data.aws_ssm_parameter.logs_key_arn.value
}
```

#### CloudWatch Alarms 설정

비정상적인 네트워크 트래픽 감지:

```hcl
# alarms.tf (새로 생성)

resource "aws_cloudwatch_metric_alarm" "nat_gateway_bytes" {
  alarm_name          = "${var.environment}-nat-gateway-high-bytes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BytesOutToDestination"
  namespace           = "AWS/NATGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 10737418240  # 10GB in 5 minutes
  alarm_description   = "NAT Gateway high data transfer"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    NatGatewayId = aws_nat_gateway.main.id
  }
}
```

### 비용 최적화

#### 1. VPC Endpoints 추가

S3, DynamoDB Gateway Endpoints는 무료이며 NAT Gateway 비용 절감:

```hcl
# vpc-endpoints.tf (새로 생성)

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-northeast-2.s3"

  route_table_ids = concat(
    [aws_route_table.public.id],
    [aws_route_table.private.id]
  )

  tags = merge(
    local.common_tags,
    {
      Name = "${var.environment}-s3-endpoint"
    }
  )
}
```

**절감 효과**: S3 트래픽이 NAT Gateway를 거치지 않아 데이터 전송 비용 절감

#### 2. NAT Gateway vs NAT Instance

트래픽이 적은 환경에서는 NAT Instance 고려:

| 구분 | NAT Gateway | NAT Instance |
|------|-------------|--------------|
| **월 비용** | ~$32 + 데이터 전송 | ~$10 (t3.nano) |
| **가용성** | AWS 관리형 (99.95%) | 직접 관리 필요 |
| **대역폭** | 최대 45 Gbps | 인스턴스 타입 의존 |
| **관리** | 불필요 | AMI 업데이트 필요 |

---

## 문제 해결

### 1. Private 서브넷에서 인터넷 연결 실패

**증상**: Private 서브넷의 인스턴스가 인터넷에 접속할 수 없음

**확인 방법**:
```bash
# NAT Gateway 상태 확인
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --region ap-northeast-2

# Private 라우트 테이블 확인
aws ec2 describe-route-tables \
  --route-table-ids $(terraform output -raw private_route_table_id) \
  --region ap-northeast-2
```

**해결 방법**:
1. NAT Gateway 상태가 `available`인지 확인
2. Private 라우트 테이블에 `0.0.0.0/0 → NAT Gateway` 라우트 확인
3. 보안 그룹에서 아웃바운드 트래픽 허용 확인

### 2. Transit Gateway VPC 간 통신 불가

**증상**: Transit Gateway를 통한 다른 VPC 접근 실패

**확인 방법**:
```bash
# Transit Gateway Attachment 상태
aws ec2 describe-transit-gateway-attachments \
  --filters "Name=transit-gateway-id,Values=$(terraform output -raw transit_gateway_id)" \
  --region ap-northeast-2

# Transit Gateway 라우트 확인
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id $(terraform output -raw transit_gateway_route_table_id) \
  --filters "Name=state,Values=active" \
  --region ap-northeast-2
```

**해결 방법**:
1. **VPC Attachment 상태**: `available`인지 확인
2. **라우팅 테이블**: 양쪽 VPC 모두 상대방 CIDR로 가는 라우트 확인
3. **보안 그룹**: 다른 VPC CIDR 블록을 허용하는지 확인
4. **Transit Gateway 라우트**: Propagation이 활성화되어 있는지 확인

### 3. CIDR 블록 충돌

**증상**: 새로운 VPC 생성 시 CIDR 충돌 에러

**확인 방법**:
```bash
# 모든 VPC CIDR 확인
aws ec2 describe-vpcs \
  --region ap-northeast-2 \
  --query 'Vpcs[*].{VpcId:VpcId,CidrBlock:CidrBlock}'
```

**해결 방법**:

CIDR 계획:
```
Prod VPC:    10.0.0.0/16
Dev VPC:     10.1.0.0/16
Staging VPC: 10.2.0.0/16
Shared VPC:  10.10.0.0/16
```

### 4. SSM Parameter 참조 실패

**증상**: 다른 스택에서 `/shared/network/*` Parameter를 찾을 수 없음

**확인 방법**:
```bash
# SSM Parameter 확인
aws ssm get-parameters-by-path \
  --path /shared/network \
  --recursive \
  --region ap-northeast-2
```

**해결 방법**:
1. **Region 확인**: SSM Parameter는 region-specific 리소스
2. **IAM 권한**: 다른 스택의 실행 Role에 SSM 읽기 권한 부여
3. **Parameter 생성**: `terraform apply` 실행하여 Parameter 생성 확인

필요한 IAM 정책:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ],
    "Resource": "arn:aws:ssm:ap-northeast-2:*:parameter/shared/*"
  }]
}
```

### 5. Terraform Import 실패

**증상**: 기존 AWS 리소스를 Terraform으로 import 실패

**Import 명령어 예시**:

```bash
# VPC Import
terraform import aws_vpc.main vpc-xxxxxxxxx

# Public Subnet Import
terraform import 'aws_subnet.public[0]' subnet-xxxxxxxxx
terraform import 'aws_subnet.public[1]' subnet-yyyyyyyyy

# Private Subnet Import
terraform import 'aws_subnet.private[0]' subnet-zzzzzzzzz
terraform import 'aws_subnet.private[1]' subnet-aaaaaaaaa

# Internet Gateway Import
terraform import aws_internet_gateway.main igw-xxxxxxxxx

# NAT Gateway Import
terraform import aws_nat_gateway.main nat-xxxxxxxxx

# Route Tables Import
terraform import aws_route_table.public rtb-xxxxxxxxx
terraform import aws_route_table.private rtb-yyyyyyyyy
```

**주의사항**:
- Import 후 `terraform plan`으로 변경 사항 확인
- `lifecycle { ignore_changes = [tags] }` 설정으로 AWS Console에서 관리하는 태그 보존

---

## 보안 고려사항

### 필수 보안 설정

- [ ] **VPC Flow Logs**: 모든 네트워크 트래픽 로깅 활성화
- [ ] **Private 서브넷 격리**: IGW 직접 라우팅 금지, NAT Gateway만 사용
- [ ] **보안 그룹 최소화**: `0.0.0.0/0` 규칙 최소화, 필요한 포트만 허용
- [ ] **Transit Gateway**: Private 서브넷만 연결, Public 서브넷 연결 금지
- [ ] **SSM Parameter 암호화**: KMS 암호화 적용 (현재는 String 타입)

### 권장 보안 설정

- [ ] **VPC Endpoints**: S3, DynamoDB Gateway Endpoint 생성 (비용 절감 + 보안 강화)
- [ ] **Network ACL**: 추가 방어 계층 구성 (Stateless 필터링)
- [ ] **CloudWatch Alarms**: 비정상 트래픽 패턴 감지
- [ ] **Config Rules**: VPC 보안 설정 자동 검증
- [ ] **CloudTrail**: VPC 변경 사항 감사 로깅

---

## 버전 히스토리

| 버전 | 날짜 | 변경 사항 |
|------|------|-----------|
| 1.0.0 | 2024-11-24 | 초기 문서화 (modules v1.0.0 패턴 기준) |

---

## 관련 문서

- [AWS VPC 사용자 가이드](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [AWS Transit Gateway 문서](https://docs.aws.amazon.com/vpc/latest/tgw/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Infrastructure 프로젝트 거버넌스](../../../docs/governance/)

---

**Maintained By**: Platform Team
**Last Updated**: 2024-11-24
