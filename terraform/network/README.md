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

1. **Private 서브넷만 연결**
   - Public 서브넷은 Transit Gateway에 연결하지 않음
   - 인터넷 트래픽은 Internet Gateway/NAT Gateway 사용

2. **보안 그룹 설정**
   - VPC 간 통신을 위한 보안 그룹 규칙 추가 필요
   - 최소 권한 원칙 적용

3. **네트워크 ACL**
   - 필요시 추가 네트워크 제어 레이어 구성

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

## Related JIRAs

- **IN-109**: VPC 및 네트워크 구성 (기본 인프라) - ✅ Merged
- **IN-110**: Transit Gateway 구성 (이 문서)

## References

- [AWS Transit Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/tgw/)
- [Transit Gateway Best Practices](https://docs.aws.amazon.com/vpc/latest/tgw/tgw-best-design-practices.html)
- [Terraform AWS Provider - Transit Gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway)
