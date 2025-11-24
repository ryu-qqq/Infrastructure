# Shared VPC (Import용)

현재 운영 중인 AWS VPC를 Terraform State로 가져오기 위한 설정

## 📋 개요

이 디렉토리는 **기존에 배포된 VPC를 Terraform으로 관리**하기 위한 것입니다.

### 목적

1. **기존 VPC Import**: 이미 운영 중인 VPC를 Terraform State로 가져옴
2. **SSM Parameter 생성**: Cross-stack 참조를 위한 Parameter 자동 생성
3. **공유 인프라 관리**: 다른 프로젝트가 이 VPC를 참조할 수 있게 함

### 템플릿과의 차이

| 항목 | templates/vpc/ | shared/vpc/ |
|------|----------------|-------------|
| 용도 | 새 VPC 생성용 템플릿 | 기존 VPC import용 |
| lifecycle | 없음 | `ignore_changes = [tags]` |
| Backend | 주석 처리 | 실제 S3 backend 설정 |
| 변수 | 예제 값 | 실제 운영 값 |

## 🚀 Import 절차

### 1. 리소스 ID 확인

AWS CLI로 실제 리소스 ID를 확인합니다:

```bash
# VPC ID 확인
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=prod-*-vpc" \
  --query 'Vpcs[0].VpcId' --output text

# Internet Gateway ID 확인
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=<VPC_ID>" \
  --query 'InternetGateways[0].InternetGatewayId' --output text

# Subnet IDs 확인
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# NAT Gateway IDs 확인
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=<VPC_ID>" \
  --query 'NatGateways[*].[NatGatewayId,SubnetId,State]' \
  --output table

# Elastic IP IDs 확인
aws ec2 describe-addresses \
  --filters "Name=domain,Values=vpc" \
  --query 'Addresses[*].[AllocationId,PublicIp,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Route Table IDs 확인
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

### 2. import.sh 수정

`import.sh` 파일을 열고 실제 리소스 ID로 수정:

```bash
# RESOURCE IDS 섹션을 실제 값으로 수정
VPC_ID="vpc-0abc123def456"
IGW_ID="igw-0abc123def456"
PUBLIC_SUBNET_1="subnet-0abc123def456"
# ... 나머지도 수정
```

### 3. terraform.tfvars 확인

현재 VPC 설정과 일치하는지 확인:

```hcl
project_name = "connectly"
environment  = "prod"
vpc_cidr     = "10.0.0.0/16"  # 실제 VPC CIDR과 일치해야 함

# 실제 서브넷 CIDR과 일치해야 함
public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
```

### 4. Import 실행

```bash
# Import 스크립트 실행
./import.sh

# 결과 확인
terraform state list

# Plan으로 변경사항 확인 (변경이 없어야 정상)
terraform plan
```

**예상 결과**: `No changes. Your infrastructure matches the configuration.`

### 5. SSM Parameters 생성

Import가 완료되면 SSM Parameters를 생성합니다:

```bash
# Apply로 SSM Parameters 생성
terraform apply

# 생성된 Parameters 확인
aws ssm get-parameters-by-path \
  --path "/shared/connectly/network/" \
  --query 'Parameters[*].[Name,Value]' \
  --output table
```

## 📊 생성되는 SSM Parameters

Import 후 다음 Parameters가 자동 생성됩니다:

| Parameter 이름 | 설명 | 예제 값 |
|---------------|------|---------|
| `/shared/connectly/network/vpc-id` | VPC ID | `vpc-0abc123def456` |
| `/shared/connectly/network/vpc-cidr` | VPC CIDR 블록 | `10.0.0.0/16` |
| `/shared/connectly/network/public-subnet-ids` | Public Subnet IDs (CSV) | `subnet-xxx,subnet-yyy` |
| `/shared/connectly/network/private-subnet-ids` | Private Subnet IDs (CSV) | `subnet-aaa,subnet-bbb` |

## 🔄 다른 프로젝트에서 참조하기

Import가 완료되면 다른 프로젝트에서 이 VPC를 참조할 수 있습니다:

```hcl
# 다른 프로젝트의 main.tf

# VPC ID 참조
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/connectly/network/vpc-id"
}

# Private Subnet IDs 참조
data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/shared/connectly/network/private-subnet-ids"
}

locals {
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
}

# ECS 서비스 배포 예제
resource "aws_ecs_service" "app" {
  # ...
  network_configuration {
    subnets = local.private_subnet_ids
  }
}
```

## 🧪 검증

Import가 제대로 되었는지 확인:

```bash
# 1. State에 리소스가 있는지 확인
terraform state list

# 예상 출력:
# aws_vpc.main
# aws_internet_gateway.main
# aws_subnet.public[0]
# aws_subnet.public[1]
# ...

# 2. Plan에서 변경사항이 없는지 확인
terraform plan

# 예상 출력:
# No changes. Your infrastructure matches the configuration.

# 3. SSM Parameters 확인
aws ssm get-parameter --name "/shared/connectly/network/vpc-id"
```

## ⚠️ 주의사항

### lifecycle ignore_changes

모든 리소스에 `lifecycle { ignore_changes = [tags] }`가 설정되어 있습니다:

```hcl
resource "aws_vpc" "main" {
  # ...
  lifecycle {
    ignore_changes = [tags]  # 기존 태그 보존
  }
}
```

**이유**: 기존 VPC의 태그를 수정하지 않기 위함 (IAM 권한 제약 또는 의도적 보존)

### Import 시 주의점

1. **CIDR 블록 일치**: `terraform.tfvars`의 CIDR이 실제 VPC와 정확히 일치해야 함
2. **서브넷 순서**: AZ 순서가 일치해야 함 (ap-northeast-2a → 2b)
3. **NAT Gateway 개수**:
   - HA 구성: `single_nat_gateway = false` (NAT Gateway 2개)
   - 비용 절감: `single_nat_gateway = true` (NAT Gateway 1개)
4. **Route Table Associations**: 자동으로 import되지 않음 (수동 import 필요)

### 백업 권장

Import 전에 현재 VPC 설정을 백업:

```bash
# VPC 정보 백업
aws ec2 describe-vpcs --vpc-ids <VPC_ID> > vpc-backup.json
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<VPC_ID>" > subnets-backup.json
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<VPC_ID>" > route-tables-backup.json
```

## 🔧 트러블슈팅

### Import 실패

**문제**: `Error: resource already managed by Terraform`

**해결**:
```bash
# State에서 제거 후 다시 import
terraform state rm aws_vpc.main
terraform import aws_vpc.main <VPC_ID>
```

### Plan에서 변경사항 발견

**문제**: Import 후 `terraform plan`에서 변경사항이 나타남

**해결**:
1. `terraform.tfvars`의 값이 실제 리소스와 일치하는지 확인
2. CIDR 블록, AZ, 서브넷 개수 등을 실제 값과 비교
3. 불일치하는 항목을 `terraform.tfvars`에서 수정

### SSM Parameter 권한 에러

**문제**: `Error: error creating SSM parameter: AccessDeniedException`

**해결**:
```bash
# IAM 정책에 SSM 권한 추가
{
  "Effect": "Allow",
  "Action": [
    "ssm:PutParameter",
    "ssm:AddTagsToResource"
  ],
  "Resource": "arn:aws:ssm:*:*:parameter/shared/*"
}
```

## 📚 참고

- [Terraform Import 공식 문서](https://www.terraform.io/docs/cli/import/index.html)
- [AWS VPC 리소스 확인 가이드](https://docs.aws.amazon.com/vpc/latest/userguide/)
- 새 VPC 생성이 필요하면: `terraform/templates/vpc/` 사용

---

**유지보수**: Platform Team
**최종 업데이트**: 2025-11-21
