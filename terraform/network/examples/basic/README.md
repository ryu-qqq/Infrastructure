# Network Basic Example

기본 VPC 및 서브넷 구성 예제입니다.

## 개요

이 예제에서는 다음 리소스를 생성합니다:

- **VPC**: /16 CIDR 블록
- **Public Subnets**: 2개 (Multi-AZ)
- **Private Subnets**: 2개 (Multi-AZ)
- **Internet Gateway**: 외부 인터넷 접근
- **NAT Gateways**: Private 서브넷의 아웃바운드 통신
- **Route Tables**: 서브넷별 라우팅 설정

## 네트워크 구조

```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.0.0/20, 10.0.16.0/20)
│   ├── Internet Gateway
│   └── Public Route Table
└── Private Subnets (10.0.128.0/19, 10.0.160.0/19)
    ├── NAT Gateways (2개, Multi-AZ)
    └── Private Route Tables
```

## 사용 방법

### terraform.tfvars

```hcl
environment = "dev"
vpc_cidr    = "10.0.0.0/16"

# 서브넷 CIDR 블록
public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20"]
private_subnet_cidrs = ["10.0.128.0/19", "10.0.160.0/19"]

# Availability Zones
availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]

# NAT Gateway 설정
enable_nat_gateway     = true
single_nat_gateway     = false  # Multi-AZ 권장
one_nat_gateway_per_az = true
```

### 배포

```bash
terraform init
terraform plan
terraform apply
```

## 주요 설정

### NAT Gateway 전략

**옵션 1: Multi-AZ (권장)**
```hcl
single_nat_gateway     = false
one_nat_gateway_per_az = true
```
- 비용: ~$65/월 (NAT Gateway 2개)
- 장점: 고가용성, AZ 장애 시에도 작동
- 단점: 비용 증가

**옵션 2: Single NAT**
```hcl
single_nat_gateway = true
```
- 비용: ~$32/월 (NAT Gateway 1개)
- 장점: 비용 절감
- 단점: 단일 장애 지점 (SPOF)

## 비용 예상

서울 리전 기준 월 비용:

| 리소스 | 수량 | 비용 (USD) |
|--------|------|------------|
| VPC | 1 | 무료 |
| Internet Gateway | 1 | 무료 |
| NAT Gateway | 2 | ~$65 |
| **총 예상** | | **~$65** |

> NAT Gateway는 시간당 $0.059 + 데이터 처리 비용

## Outputs

```bash
terraform output vpc_id
terraform output public_subnet_ids
terraform output private_subnet_ids
terraform output nat_gateway_ids
```

## 참고

- [Network 패키지 문서](../../README.md)
- [AWS VPC 문서](https://docs.aws.amazon.com/vpc/)
