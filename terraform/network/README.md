# Network Infrastructure

VPC, 서브넷, NAT Gateway, Transit Gateway를 포함한 네트워크 인프라 구성

## 개요

이 모듈은 다음 네트워크 리소스를 관리합니다:
- VPC (10.0.0.0/16)
- Multi-AZ Public/Private 서브넷
- Internet Gateway 및 NAT Gateway
- **Transit Gateway (멀티 VPC 통신)**

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                   │
│                                                               │
│  ┌──────────────────────┐  ┌──────────────────────┐         │
│  │  ap-northeast-2a     │  │  ap-northeast-2b     │         │
│  │                      │  │                      │         │
│  │  Public  10.0.0.0/24 │  │  Public  10.0.1.0/24 │         │
│  │  Private 10.0.10.0/24│  │  Private 10.0.11.0/24│         │
│  └──────────┬───────────┘  └──────────┬───────────┘         │
│             │                         │                      │
│             └────────┬────────────────┘                      │
│                      │                                       │
│              ┌───────▼────────┐                              │
│              │ Transit Gateway │                             │
│              └────────────────┘                              │
└───────────────────────┬─────────────────────────────────────┘
                        │
                   ┌────▼────┐
                   │ 향후 VPC │
                   └─────────┘
```

## Transit Gateway

### 용도
Transit Gateway는 여러 VPC 간 통신을 위한 중앙 집중식 네트워크 허브입니다.

**사용 사례:**
- 다른 환경의 VPC 간 통신 (dev, staging, prod)
- 마이크로서비스 간 VPC 분리 및 통신
- Shared Services VPC (모니터링, 로깅) 연결
- 온프레미스 네트워크와의 VPN/Direct Connect 연결

**예시 시나리오:**
```
VPC-A의 API 서버 (10.0.10.5) → Transit Gateway → VPC-B의 DB (10.1.10.20)
```

### 구성 요소

1. **Transit Gateway**
   - Amazon Side ASN: 64512
   - DNS 지원 활성화
   - VPN ECMP 지원 (다중 VPN 연결)
   - 자동 라우트 수락

2. **VPC Attachment**
   - 현재 VPC의 Private 서브넷을 TGW에 연결
   - 보안을 위해 Public 서브넷은 연결하지 않음

3. **라우팅**
   - Private 서브넷 → Transit Gateway 라우트 (향후 VPC 추가시)
   - 기본 라우트 테이블 사용

## Variables

### 필수 변수
```hcl
environment = "prod"  # 환경 이름
```

### Transit Gateway 변수
```hcl
enable_transit_gateway = true  # Transit Gateway 활성화 (기본값: true)

transit_gateway_asn = 64512    # Amazon Side ASN (기본값: 64512)

transit_gateway_routes = [     # TGW를 통해 라우팅할 CIDR 블록 목록
  # "10.1.0.0/16",  # 향후 VPC-B
  # "10.2.0.0/16",  # 향후 VPC-C
]
```

## Outputs

### 네트워크 정보
- `vpc_id`: VPC ID
- `vpc_cidr`: VPC CIDR 블록
- `public_subnet_ids`: Public 서브넷 ID 목록
- `private_subnet_ids`: Private 서브넷 ID 목록

### Transit Gateway 정보
- `transit_gateway_id`: Transit Gateway ID
- `transit_gateway_arn`: Transit Gateway ARN
- `transit_gateway_vpc_attachment_id`: VPC Attachment ID
- `transit_gateway_route_table_id`: Transit Gateway 기본 라우팅 테이블 ID

## 사용 예시

### 기본 사용 (Transit Gateway 활성화)
```hcl
module "network" {
  source = "./network"

  environment = "prod"
}
```

### Transit Gateway 비활성화
```hcl
module "network" {
  source = "./network"

  environment = "prod"
  enable_transit_gateway = false
}
```

### 추가 VPC 라우팅 설정
```hcl
module "network" {
  source = "./network"

  environment = "prod"
  transit_gateway_routes = [
    "10.1.0.0/16",  # VPC-B (다른 서비스)
    "10.2.0.0/16",  # VPC-C (다른 환경)
  ]
}
```

## 향후 VPC 추가 방법

새로운 VPC를 Transit Gateway에 연결하려면:

1. **새 VPC 생성 및 Attachment**
```hcl
resource "aws_ec2_transit_gateway_vpc_attachment" "new_vpc" {
  transit_gateway_id = module.network.transit_gateway_id
  vpc_id             = aws_vpc.new_vpc.id
  subnet_ids         = aws_subnet.new_private[*].id
}
```

2. **현재 VPC에 라우트 추가**
```hcl
module "network" {
  transit_gateway_routes = [
    "10.1.0.0/16",  # 새 VPC의 CIDR
  ]
}
```

3. **새 VPC에도 라우트 추가**
```hcl
resource "aws_route" "new_vpc_to_tgw" {
  route_table_id         = aws_route_table.new_private.id
  destination_cidr_block = "10.0.0.0/16"  # 현재 VPC
  transit_gateway_id     = module.network.transit_gateway_id
}
```

## 비용 고려사항

**Transit Gateway 요금:**
- 시간당 요금: ~$0.05/hour
- 데이터 전송 요금: ~$0.02/GB

**예상 월간 비용:**
- TGW 운영: ~$36/month (730시간)
- 데이터 전송: 사용량에 따라 변동

**절감 방법:**
- 현재 단일 VPC 환경에서는 `enable_transit_gateway = false`로 설정 가능
- 멀티 VPC 환경이 필요할 때만 활성화

## 보안 고려사항

### 1. VPC Flow Logs 활성화

**모든 네트워크 트래픽 로깅**:

```hcl
resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"  # ACCEPT, REJECT, ALL
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn

  tags = merge(
    local.required_tags,
    {
      Name = "${var.environment}-vpc-flow-logs"
    }
  )
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.environment}"
  retention_in_days = 30
  kms_key_id        = data.aws_ssm_parameter.logs-key-arn.value
}
```

**Flow Logs 분석 - CloudWatch Logs Insights**:
```sql
-- 가장 많은 트래픽을 발생시킨 IP
fields @timestamp, srcaddr, dstaddr, bytes
| filter action = "ACCEPT"
| stats sum(bytes) as total_bytes by srcaddr
| sort total_bytes desc
| limit 20

-- 거부된 연결 시도 (보안 위협 탐지)
fields @timestamp, srcaddr, dstaddr, srcport, dstport, protocol
| filter action = "REJECT"
| stats count() by srcaddr, dstport
| sort count desc
| limit 50

-- 비정상적으로 많은 연결 (DDoS 탐지)
fields @timestamp, srcaddr
| filter action = "ACCEPT"
| stats count() by srcaddr, bin(5m)
| filter count > 1000  # 5분간 1000개 이상 연결
```

**VPC Flow Logs를 S3로 저장** (비용 절감):
```hcl
resource "aws_flow_log" "vpc_s3" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "s3"
  log_destination          = aws_s3_bucket.flow_logs.arn
  max_aggregation_interval = 600  # 10분 (기본 60초)

  destination_options {
    file_format        = "parquet"  # parquet는 압축률이 높음
    per_hour_partition = true
  }
}
```

### 2. 보안 그룹 규칙 최소화

**최소 권한 원칙 적용**:

```hcl
# ❌ 잘못된 예: 모든 트래픽 허용
resource "aws_security_group_rule" "bad" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
}

# ✅ 올바른 예: 특정 포트와 소스만 허용
resource "aws_security_group_rule" "good_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]  # VPC CIDR만 허용
  description       = "Allow HTTPS from VPC"
  security_group_id = aws_security_group.app.id
}

# ✅ 더 나은 예: 보안 그룹 참조로 제한
resource "aws_security_group_rule" "best" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow HTTPS from ALB only"
  security_group_id        = aws_security_group.app.id
}
```

**보안 그룹 감사 스크립트**:
```bash
# 0.0.0.0/0 규칙 검색
aws ec2 describe-security-groups \
  --region ap-northeast-2 \
  --query 'SecurityGroups[?IpPermissions[?contains(IpRanges[].CidrIp, `0.0.0.0/0`)]].[GroupId,GroupName,IpPermissions]' \
  --output table

# 미사용 보안 그룹 확인
aws ec2 describe-security-groups \
  --region ap-northeast-2 \
  --query 'SecurityGroups[?length(IpPermissions) == `0` && length(IpPermissionsEgress) == `1`].[GroupId,GroupName]' \
  --output table
```

### 3. VPC Endpoints (보안 + 비용 절감)

**프라이빗 연결로 AWS 서비스 접근**:

```hcl
# S3 Gateway Endpoint (무료)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-northeast-2.s3"

  route_table_ids = concat(
    aws_route_table.private[*].id,
    [aws_route_table.public.id]
  )

  tags = merge(
    local.required_tags,
    {
      Name = "${var.environment}-s3-endpoint"
    }
  )
}

# DynamoDB Gateway Endpoint (무료)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-northeast-2.dynamodb"

  route_table_ids = aws_route_table.private[*].id
}

# ECR Interface Endpoint (유료 ~$7/월)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-2.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# Secrets Manager Interface Endpoint (유료 ~$7/월)
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-2.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}
```

**VPC Endpoint 보안 그룹**:
```hcl
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.environment}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "Allow HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**장점**:
- ✅ 인터넷을 거치지 않아 보안 강화
- ✅ NAT Gateway 비용 절감 (S3, DynamoDB 트래픽)
- ✅ 더 낮은 지연 시간
- ✅ VPC 내부 트래픽으로만 통신

### 4. Network ACL (추가 방어 계층)

**Stateless 네트워크 필터링**:

```hcl
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Inbound 규칙
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_vpc.main.cidr_block
    from_port  = 443
    to_port    = 443
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = aws_vpc.main.cidr_block
    from_port  = 3306  # MySQL
    to_port    = 3306
  }

  # Ephemeral ports (필수 - TCP 응답용)
  ingress {
    rule_no    = 900
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound 규칙
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    local.required_tags,
    {
      Name = "${var.environment}-private-nacl"
    }
  )
}
```

**Network ACL vs Security Group**:
| 특성 | Network ACL | Security Group |
|------|-------------|----------------|
| 작동 레벨 | 서브넷 | 인스턴스/ENI |
| 상태 | Stateless | Stateful |
| 규칙 적용 | 번호 순서 | 모든 규칙 평가 |
| Deny 규칙 | 지원 | 미지원 |
| 기본 동작 | Deny | Deny |

### 5. Private Subnet 격리

**Private 서브넷은 인터넷 게이트웨이 직접 연결 금지**:

```hcl
# ❌ 잘못된 예: Private 서브넷에 IGW 라우팅
resource "aws_route" "bad_private_igw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# ✅ 올바른 예: Private 서브넷은 NAT Gateway 사용
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}
```

**서브넷 격리 검증**:
```bash
# Private 서브넷에 IGW 라우팅이 없는지 확인
aws ec2 describe-route-tables \
  --region ap-northeast-2 \
  --filters "Name=tag:Type,Values=Private" \
  --query 'RouteTables[*].Routes[?GatewayId && starts_with(GatewayId, `igw-`)]' \
  --output table

# 결과가 비어있어야 함 (Private 서브넷은 IGW 직접 접근 금지)
```

### 6. Transit Gateway 보안

**Private 서브넷만 Transit Gateway 연결**:

```hcl
resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  subnet_ids         = aws_subnet.private[*].id  # ✅ Private만
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.main.id

  # Public 서브넷은 절대 연결하지 않음
  # subnet_ids = aws_subnet.public[*].id  # ❌
}
```

**Transit Gateway Route Table 격리**:
```hcl
resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(
    local.required_tags,
    {
      Name        = "prod-tgw-rt"
      Environment = "prod"
    }
  )
}

resource "aws_ec2_transit_gateway_route_table" "dev" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = merge(
    local.required_tags,
    {
      Name        = "dev-tgw-rt"
      Environment = "dev"
    }
  )
}

# Prod와 Dev VPC 간 라우팅 분리 (격리)
```

### 7. DDoS 방어 (AWS Shield)

**AWS Shield Standard** (무료, 자동 활성화):
- Layer 3/4 DDoS 공격 방어
- CloudFront, Route 53, ALB 자동 보호

**AWS Shield Advanced** (유료 $3,000/월):
```hcl
resource "aws_shield_protection" "alb" {
  name         = "${var.environment}-alb-protection"
  resource_arn = aws_lb.main.arn
}

resource "aws_shield_protection" "eip" {
  for_each     = aws_eip.nat
  name         = "${var.environment}-nat-${each.key}-protection"
  resource_arn = each.value.arn
}
```

### 8. 보안 체크리스트

#### 네트워크 설계
- [ ] **CIDR 계획**: IP 주소 충돌 없이 설계
- [ ] **서브넷 분리**: Public, Private, Data 서브넷 명확히 분리
- [ ] **Multi-AZ**: 고가용성을 위한 최소 2개 AZ 사용
- [ ] **NAT Gateway**: Multi-AZ NAT Gateway 배치 (고가용성)
- [ ] **Transit Gateway**: Private 서브넷만 연결

#### 보안 설정
- [ ] **VPC Flow Logs**: 모든 VPC에 활성화
- [ ] **보안 그룹**: 0.0.0.0/0 규칙 최소화 (필요한 경우에만)
- [ ] **Network ACL**: 추가 방어가 필요한 경우 구성
- [ ] **VPC Endpoints**: S3, DynamoDB Gateway Endpoint 생성 (필수)
- [ ] **Private Subnet**: IGW 직접 라우팅 금지
- [ ] **공개 IP**: Private 서브넷 인스턴스는 공개 IP 비활성화

#### 모니터링 및 로깅
- [ ] **CloudWatch Alarms**: 비정상적인 트래픽 패턴 알람
- [ ] **Flow Logs 분석**: 주기적으로 거부된 연결 확인
- [ ] **CloudTrail**: VPC 변경 사항 추적
- [ ] **Config Rules**: VPC 보안 규칙 자동 검증

#### 비용 최적화
- [ ] **NAT Gateway**: Single vs Multi-AZ 환경별 선택
- [ ] **VPC Endpoints**: S3, DynamoDB Gateway Endpoint 우선 (무료)
- [ ] **Flow Logs**: S3 저장 + Parquet 포맷 (비용 절감)
- [ ] **Transit Gateway**: Attachment 당 과금 확인

#### 규정 준수
- [ ] **암호화**: VPC Flow Logs KMS 암호화
- [ ] **감사**: 모든 네트워크 변경 CloudTrail 로깅
- [ ] **접근 제어**: IAM 정책으로 네트워크 변경 제한
- [ ] **문서화**: 네트워크 다이어그램 및 CIDR 할당 문서

#### 보안 사고 대응
- [ ] **Runbook**: 네트워크 침해 대응 절차
- [ ] **격리 절차**: 침해 의심 서브넷/인스턴스 격리 방법
- [ ] **Rollback**: 네트워크 변경 롤백 계획
- [ ] **연락처**: 네트워크 관리자 및 보안팀 연락처

## Terraform 명령어

```bash
# 초기화
terraform init

# 검증
terraform validate

# Plan (변경 사항 미리보기)
terraform plan -var="environment=prod"

# Apply (실제 배포)
terraform apply -var="environment=prod"

# Destroy (리소스 삭제)
terraform destroy -var="environment=prod"
```

## Troubleshooting

### 1. VPC 간 통신 불가

**증상**: Transit Gateway를 통한 VPC 간 통신이 안 됨

**확인 방법**:
```bash
# Transit Gateway 상태 확인
aws ec2 describe-transit-gateways \
  --transit-gateway-ids $(terraform output -raw transit_gateway_id) \
  --region ap-northeast-2

# VPC Attachment 상태 확인
aws ec2 describe-transit-gateway-attachments \
  --filters "Name=transit-gateway-id,Values=$(terraform output -raw transit_gateway_id)" \
  --region ap-northeast-2
```

**해결 방법**:

1. **라우팅 테이블 확인**:
   ```bash
   # Private 서브넷 라우팅 테이블 확인
   aws ec2 describe-route-tables \
     --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
     --region ap-northeast-2 \
     --query 'RouteTables[*].{RouteTableId:RouteTableId,Routes:Routes}'
   ```
   - Transit Gateway로 가는 라우트가 있는지 확인
   - 목적지 CIDR이 정확한지 확인

2. **보안 그룹 규칙 확인**:
   - 두 VPC의 보안 그룹이 서로의 CIDR 블록을 허용하는지 확인
   ```bash
   # 보안 그룹 규칙 확인
   aws ec2 describe-security-groups \
     --group-ids <security-group-id> \
     --region ap-northeast-2 \
     --query 'SecurityGroups[*].{Ingress:IpPermissions}'
   ```

3. **Transit Gateway 라우팅 테이블**:
   ```bash
   # TGW 라우팅 테이블 확인
   aws ec2 describe-transit-gateway-route-tables \
     --transit-gateway-route-table-ids $(terraform output -raw transit_gateway_route_table_id) \
     --region ap-northeast-2

   # TGW 라우트 확인
   aws ec2 search-transit-gateway-routes \
     --transit-gateway-route-table-id $(terraform output -raw transit_gateway_route_table_id) \
     --filters "Name=state,Values=active" \
     --region ap-northeast-2
   ```

### 2. NAT Gateway를 통한 인터넷 연결 실패

**증상**: Private 서브넷의 인스턴스가 인터넷에 접속 불가

**확인 방법**:
```bash
# NAT Gateway 상태 확인
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --region ap-northeast-2

# Private 서브넷 라우팅 확인
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --region ap-northeast-2 \
  --query 'RouteTables[?Associations[?SubnetId]].{RouteTableId:RouteTableId,SubnetId:Associations[0].SubnetId,Routes:Routes}'
```

**해결 방법**:

1. **NAT Gateway 상태 확인**:
   - State가 `available`인지 확인
   - NAT Gateway가 Public 서브넷에 있는지 확인
   - Elastic IP가 할당되어 있는지 확인

2. **라우팅 테이블 검증**:
   - Private 서브넷의 라우팅 테이블에 `0.0.0.0/0 → NAT Gateway` 라우트 확인
   ```bash
   # 기대하는 라우트:
   # 0.0.0.0/0 → nat-xxxxx
   ```

3. **네트워크 ACL 확인**:
   ```bash
   # Network ACL 확인
   aws ec2 describe-network-acls \
     --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
     --region ap-northeast-2
   ```
   - Outbound rule에서 인터넷(0.0.0.0/0)으로의 트래픽 허용 확인
   - Inbound rule에서 응답 트래픽(ephemeral ports) 허용 확인

### 3. Internet Gateway 연결 문제

**증상**: Public 서브넷에서 인터넷 연결 안 됨

**확인 방법**:
```bash
# Internet Gateway 상태 확인
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$(terraform output -raw vpc_id)" \
  --region ap-northeast-2

# Public 서브넷 라우팅 확인
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --region ap-northeast-2
```

**해결 방법**:

1. **Internet Gateway Attachment 확인**:
   - IGW가 VPC에 연결되어 있는지 확인
   - State가 `available`인지 확인

2. **Public 서브넷 라우팅**:
   - Public 서브넷 라우팅 테이블에 `0.0.0.0/0 → IGW` 라우트 확인
   ```bash
   # 기대하는 라우트:
   # 0.0.0.0/0 → igw-xxxxx
   ```

3. **Public IP 할당**:
   - 인스턴스에 Public IP 또는 Elastic IP가 할당되어 있는지 확인

### 4. CIDR 충돌 문제

**증상**: 새로운 VPC 생성 시 CIDR 블록 충돌

**확인 방법**:
```bash
# 모든 VPC의 CIDR 확인
aws ec2 describe-vpcs \
  --region ap-northeast-2 \
  --query 'Vpcs[*].{VpcId:VpcId,CidrBlock:CidrBlock,Tags:Tags}'

# Transit Gateway에 연결된 모든 VPC의 CIDR 확인
aws ec2 describe-transit-gateway-attachments \
  --filters "Name=transit-gateway-id,Values=$(terraform output -raw transit_gateway_id)" \
  --region ap-northeast-2
```

**해결 방법**:

1. **CIDR 계획**:
   - 현재 VPC: 10.0.0.0/16
   - 새 VPC: 10.1.0.0/16, 10.2.0.0/16 등 겹치지 않는 범위 사용

2. **서브넷 CIDR 확인**:
   ```bash
   # 모든 서브넷 CIDR 확인
   aws ec2 describe-subnets \
     --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
     --region ap-northeast-2 \
     --query 'Subnets[*].{SubnetId:SubnetId,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone}'
   ```

3. **권장 CIDR 구조**:
   ```
   VPC-A (prod):    10.0.0.0/16
   VPC-B (staging): 10.1.0.0/16
   VPC-C (dev):     10.2.0.0/16
   VPC-D (shared):  10.10.0.0/16
   ```

### 5. Transit Gateway Attachment 문제

**증상**: VPC가 Transit Gateway에 연결되지 않음

**확인 방법**:
```bash
# Attachment 상태 확인
aws ec2 describe-transit-gateway-vpc-attachments \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --region ap-northeast-2

# Attachment 세부 정보
aws ec2 describe-transit-gateway-vpc-attachments \
  --transit-gateway-attachment-ids $(terraform output -raw transit_gateway_vpc_attachment_id) \
  --region ap-northeast-2
```

**해결 방법**:

1. **Attachment State 확인**:
   - State: `available` (정상)
   - State: `pending` (진행 중)
   - State: `failed` (실패 - 서브넷 또는 권한 문제)

2. **서브넷 가용성 영역**:
   - 최소 2개 이상의 서브넷 (Multi-AZ) 연결 확인
   - 각 서브넷이 서로 다른 AZ에 있는지 확인

3. **IAM 권한**:
   - Transit Gateway 생성 및 Attachment 권한 확인

### 6. 라우팅 테이블 우선순위 문제

**증상**: 특정 트래픽이 의도하지 않은 경로로 라우팅됨

**확인 방법**:
```bash
# 라우팅 테이블 모든 라우트 확인
aws ec2 describe-route-tables \
  --route-table-ids <route-table-id> \
  --region ap-northeast-2 \
  --query 'RouteTables[*].Routes'
```

**해결 방법**:

1. **라우팅 우선순위 이해**:
   - 가장 구체적인(longest prefix match) 라우트가 우선
   - 예: `10.1.0.0/24` > `10.1.0.0/16` > `10.0.0.0/8` > `0.0.0.0/0`

2. **라우팅 충돌 확인**:
   ```
   # 예시 (문제 상황):
   10.0.0.0/16 → local
   10.0.10.0/24 → tgw-xxx  # 더 구체적 - 이것이 우선
   0.0.0.0/0 → igw-xxx
   ```

3. **Transit Gateway 라우트 propagation**:
   - Auto-accept 설정 확인
   - Propagated routes 확인

### 7. VPC 엔드포인트 접근 문제

**증상**: S3, ECR 등 AWS 서비스 접근 실패

**확인 방법**:
```bash
# VPC 엔드포인트 확인
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)" \
  --region ap-northeast-2
```

**해결 방법**:

1. **VPC 엔드포인트 타입**:
   - Gateway 엔드포인트: S3, DynamoDB (무료)
   - Interface 엔드포인트: ECR, Secrets Manager 등 (시간당 요금)

2. **라우팅 테이블 연결**:
   - Gateway 엔드포인트는 라우팅 테이블에 자동 추가됨
   - Private 서브넷 라우팅 테이블에 연결되었는지 확인

3. **보안 그룹 (Interface 엔드포인트)**:
   - 포트 443 인바운드 허용
   - VPC CIDR에서의 접근 허용

### 8. 하이브리드 인프라: Application 레포에서 SSM Parameter 참조 실패

**증상**: Application 프로젝트에서 `/shared/network/*` SSM Parameter를 찾을 수 없음

**확인 방법**:
```bash
# Infrastructure 프로젝트에서 SSM Parameter가 생성되었는지 확인
aws ssm get-parameters-by-path \
  --path /shared/network \
  --recursive \
  --region ap-northeast-2

# 특정 Parameter 확인
aws ssm get-parameter \
  --name /shared/network/vpc-id \
  --region ap-northeast-2
```

**해결 방법**:

1. **SSM Parameter Export 확인** (Infrastructure 프로젝트):
   ```hcl
   # outputs.tf에 SSM Parameter 리소스가 있는지 확인
   resource "aws_ssm_parameter" "vpc_id" {
     name  = "/shared/network/vpc-id"
     type  = "String"
     value = aws_vpc.main.id

     tags = merge(
       local.required_tags,
       {
         Name = "vpc-id-export"
       }
     )
   }
   ```

2. **Region 일치 확인**:
   - Infrastructure 프로젝트와 Application 프로젝트의 AWS region이 동일한지 확인
   - SSM Parameter는 region-specific 리소스

3. **IAM 권한 확인**:
   ```bash
   # Application 프로젝트의 IAM role에 SSM 읽기 권한 확인
   aws iam get-role-policy \
     --role-name <terraform-execution-role> \
     --policy-name SSMReadPolicy
   ```

   필요한 정책:
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

4. **Terraform Data Source 확인** (Application 프로젝트):
   ```hcl
   # data.tf에서 올바른 data source 사용 확인
   data "aws_ssm_parameter" "vpc_id" {
     name = "/shared/network/vpc-id"
   }

   # locals.tf에서 참조
   locals {
     vpc_id = data.aws_ssm_parameter.vpc_id.value
   }
   ```

### 9. 하이브리드 인프라: Transit Gateway 멀티 VPC 통신 문제

**증상**: Application VPC에서 Infrastructure VPC의 리소스(Shared RDS 등)에 접근 불가

**확인 방법**:
```bash
# Transit Gateway Attachment 확인
aws ec2 describe-transit-gateway-attachments \
  --filters "Name=transit-gateway-id,Values=<tgw-id>" \
  --region ap-northeast-2 \
  --query 'TransitGatewayAttachments[*].{State:State,VpcId:ResourceId,AttachmentId:TransitGatewayAttachmentId}'

# Transit Gateway 라우팅 테이블 확인
aws ec2 describe-transit-gateway-route-tables \
  --transit-gateway-route-table-ids <tgw-route-table-id> \
  --region ap-northeast-2
```

**해결 방법**:

1. **Application VPC의 TGW Attachment 생성**:

   Application 프로젝트의 Terraform 코드:
   ```hcl
   # network.tf (Application 프로젝트)
   data "aws_ssm_parameter" "transit_gateway_id" {
     name = "/shared/network/transit-gateway-id"
   }

   resource "aws_ec2_transit_gateway_vpc_attachment" "app" {
     subnet_ids         = local.private_subnet_ids
     transit_gateway_id = data.aws_ssm_parameter.transit_gateway_id.value
     vpc_id             = aws_vpc.app.id

     tags = merge(
       local.required_tags,
       {
         Name = "app-tgw-attachment"
       }
     )
   }
   ```

2. **라우팅 테이블 업데이트**:

   Application VPC의 Private 서브넷 라우팅:
   ```hcl
   resource "aws_route" "to_infrastructure" {
     route_table_id         = aws_route_table.private.id
     destination_cidr_block = "10.0.0.0/16"  # Infrastructure VPC CIDR
     transit_gateway_id     = data.aws_ssm_parameter.transit_gateway_id.value
   }
   ```

3. **보안 그룹 규칙 추가**:

   Infrastructure VPC의 RDS 보안 그룹:
   ```hcl
   # Infrastructure 프로젝트
   resource "aws_security_group_rule" "rds_from_app_vpc" {
     type              = "ingress"
     from_port         = 3306
     to_port           = 3306
     protocol          = "tcp"
     cidr_blocks       = ["10.1.0.0/16"]  # Application VPC CIDR
     security_group_id = aws_security_group.rds.id
     description       = "Allow MySQL from Application VPC"
   }
   ```

4. **Transit Gateway Auto-Accept 확인**:
   ```bash
   # TGW 설정 확인
   aws ec2 describe-transit-gateways \
     --transit-gateway-ids <tgw-id> \
     --region ap-northeast-2 \
     --query 'TransitGateways[0].Options.AutoAcceptSharedAttachments'
   ```

   값이 `enable`이어야 합니다.

5. **연결 테스트**:
   ```bash
   # Application VPC의 ECS Task에서 RDS 연결 테스트
   aws ecs execute-command \
     --cluster <app-cluster> \
     --task <task-id> \
     --container <container-name> \
     --interactive \
     --command "/bin/bash"

   # Container 내부에서
   nc -zv <rds-endpoint> 3306
   # 또는
   mysql -h <rds-endpoint> -u <username> -p
   ```

### 10. 하이브리드 인프라: Cross-Account VPC Peering 문제

**증상**: 다른 AWS 계정의 VPC와 Peering 연결이 안 됨

**확인 방법**:
```bash
# VPC Peering Connection 상태 확인
aws ec2 describe-vpc-peering-connections \
  --filters "Name=status-code,Values=pending-acceptance,active,failed" \
  --region ap-northeast-2

# Peering Connection 세부 정보
aws ec2 describe-vpc-peering-connections \
  --vpc-peering-connection-ids <pcx-id> \
  --region ap-northeast-2
```

**해결 방법**:

1. **Requester VPC에서 Peering Connection 생성**:
   ```hcl
   # Infrastructure 프로젝트 (Account A)
   resource "aws_vpc_peering_connection" "cross_account" {
     vpc_id      = aws_vpc.main.id
     peer_vpc_id = "vpc-xxxxxxxx"
     peer_owner_id = "123456789012"  # Target AWS Account ID
     peer_region = "ap-northeast-2"

     tags = merge(
       local.required_tags,
       {
         Name = "infra-to-partner-peering"
         Side = "Requester"
       }
     )
   }
   ```

2. **Accepter VPC에서 승인** (Target Account):
   ```hcl
   # Partner Account Terraform
   resource "aws_vpc_peering_connection_accepter" "peer" {
     vpc_peering_connection_id = "pcx-xxxxxxxx"
     auto_accept               = true

     tags = {
       Name = "accept-infra-peering"
       Side = "Accepter"
     }
   }
   ```

3. **양쪽 라우팅 테이블 업데이트**:

   Requester VPC:
   ```hcl
   resource "aws_route" "to_partner" {
     route_table_id            = aws_route_table.private.id
     destination_cidr_block    = "10.10.0.0/16"  # Partner VPC CIDR
     vpc_peering_connection_id = aws_vpc_peering_connection.cross_account.id
   }
   ```

   Accepter VPC:
   ```hcl
   resource "aws_route" "to_infra" {
     route_table_id            = aws_route_table.private.id
     destination_cidr_block    = "10.0.0.0/16"  # Infrastructure VPC CIDR
     vpc_peering_connection_id = data.aws_vpc_peering_connection.peer.id
   }
   ```

4. **IAM 권한 확인**:

   Requester Account에 필요한 권한:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": [
         "ec2:CreateVpcPeeringConnection",
         "ec2:DescribeVpcPeeringConnections"
       ],
       "Resource": "*"
     }]
   }
   ```

   Accepter Account에 필요한 권한:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Action": [
         "ec2:AcceptVpcPeeringConnection",
         "ec2:DescribeVpcPeeringConnections"
       ],
       "Resource": "*"
     }]
   }
   ```

5. **보안 그룹 규칙 추가**:

   양쪽 VPC 모두:
   ```hcl
   resource "aws_security_group_rule" "from_peered_vpc" {
     type              = "ingress"
     from_port         = 0
     to_port           = 65535
     protocol          = "tcp"
     cidr_blocks       = ["<peered-vpc-cidr>"]
     security_group_id = aws_security_group.main.id
     description       = "Allow traffic from peered VPC"
   }
   ```

6. **DNS Resolution 설정** (선택사항):
   ```hcl
   resource "aws_vpc_peering_connection_options" "requester" {
     vpc_peering_connection_id = aws_vpc_peering_connection.cross_account.id

     requester {
       allow_remote_vpc_dns_resolution = true
     }
   }
   ```

### 11. 일반적인 체크리스트

네트워크 배포 후 확인 사항:

#### 기본 네트워크
- [ ] VPC가 `available` 상태
- [ ] Public/Private 서브넷이 각각 2개 이상 (Multi-AZ)
- [ ] Internet Gateway가 VPC에 연결됨
- [ ] NAT Gateway가 `available` 상태
- [ ] Public 서브넷 라우팅: `0.0.0.0/0 → IGW`
- [ ] Private 서브넷 라우팅: `0.0.0.0/0 → NAT`
- [ ] 보안 그룹 규칙이 올바르게 설정됨
- [ ] CIDR 블록 충돌 없음

#### Transit Gateway (하이브리드 인프라)
- [ ] Transit Gateway가 `available` 상태
- [ ] VPC Attachment가 `available` 상태
- [ ] Transit Gateway 라우팅 테이블 구성 완료
- [ ] Private 서브넷에 TGW로 가는 라우트 추가
- [ ] 보안 그룹에 다른 VPC CIDR 허용 규칙 추가

#### SSM Parameters (하이브리드 인프라)
- [ ] `/shared/network/vpc-id` 생성됨
- [ ] `/shared/network/public-subnet-ids` 생성됨
- [ ] `/shared/network/private-subnet-ids` 생성됨
- [ ] `/shared/network/transit-gateway-id` 생성됨 (활성화 시)
- [ ] Application 프로젝트에서 SSM Parameter 읽기 권한 확인

## Related JIRAs

- **IN-109**: VPC 및 네트워크 구성 (기본 인프라) - ✅ Merged
- **IN-110**: Transit Gateway 구성 (이 문서)

## References

- [AWS Transit Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/tgw/)
- [Transit Gateway Best Practices](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-best-design-practices.html)
- [Terraform AWS Provider - Transit Gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway)

---

**Last Updated**: 2025-01-22
**Maintained By**: Platform Team
