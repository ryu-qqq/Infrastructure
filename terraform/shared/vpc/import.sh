#!/bin/bash

# ============================================================================
# VPC Import Script - Shared VPC
# ============================================================================
#
# 현재 운영 중인 VPC (vpc-0f162b9e588276e09)를 Terraform State로 import
#
# ============================================================================

set -e  # 에러 발생 시 즉시 중단

echo "🚀 VPC Import 시작..."
echo ""

# ============================================================================
# RESOURCE IDS - 확인된 실제 리소스 ID
# ============================================================================

VPC_ID="vpc-0f162b9e588276e09"
IGW_ID="igw-03a6179c98a753fe1"

# Public Subnets (ap-northeast-2a, ap-northeast-2b)
PUBLIC_SUBNET_1="subnet-0bd2fc282b0fb137a"  # 10.0.0.0/24, ap-northeast-2a
PUBLIC_SUBNET_2="subnet-0c8c0ad85064b80bb"  # 10.0.1.0/24, ap-northeast-2b

# Private Subnets (ap-northeast-2a, ap-northeast-2b)
PRIVATE_SUBNET_1="subnet-09692620519f86cf0"  # 10.0.10.0/24, ap-northeast-2a
PRIVATE_SUBNET_2="subnet-0d99080cbe134b6e9"  # 10.0.11.0/24, ap-northeast-2b

# NAT Gateway (single_nat_gateway=true, 1개만 존재)
NAT_GW="nat-03aa0c1f46689d192"
EIP="eipalloc-01c2858341e04d23c"

# Route Tables
PUBLIC_RT="rtb-0157736c003f7dea4"
PRIVATE_RT="rtb-0354d9c58fb5e0662"

# ============================================================================
# Import 실행
# ============================================================================

echo "📋 리소스 ID 확인:"
echo "  VPC: $VPC_ID"
echo "  IGW: $IGW_ID"
echo "  Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "  Private Subnets: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"
echo "  NAT Gateway: $NAT_GW (single)"
echo "  EIP: $EIP"
echo "  Route Tables: $PUBLIC_RT (public), $PRIVATE_RT (private)"
echo ""

read -p "계속하시겠습니까? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Import 취소됨"
    exit 1
fi

echo ""
echo "1️⃣ Terraform 초기화..."
terraform init

echo ""
echo "2️⃣ VPC Import..."
terraform import aws_vpc.main "$VPC_ID" || echo "⚠️  이미 import됨"

echo ""
echo "3️⃣ Internet Gateway Import..."
terraform import aws_internet_gateway.main "$IGW_ID" || echo "⚠️  이미 import됨"

echo ""
echo "4️⃣ Public Subnets Import..."
terraform import 'aws_subnet.public[0]' "$PUBLIC_SUBNET_1" || echo "⚠️  이미 import됨"
terraform import 'aws_subnet.public[1]' "$PUBLIC_SUBNET_2" || echo "⚠️  이미 import됨"

echo ""
echo "5️⃣ Private Subnets Import..."
terraform import 'aws_subnet.private[0]' "$PRIVATE_SUBNET_1" || echo "⚠️  이미 import됨"
terraform import 'aws_subnet.private[1]' "$PRIVATE_SUBNET_2" || echo "⚠️  이미 import됨"

echo ""
echo "6️⃣ NAT Gateway Elastic IP Import (single)..."
terraform import 'aws_eip.nat[0]' "$EIP" || echo "⚠️  이미 import됨"

echo ""
echo "7️⃣ NAT Gateway Import (single)..."
terraform import 'aws_nat_gateway.main[0]' "$NAT_GW" || echo "⚠️  이미 import됨"

echo ""
echo "8️⃣ Route Tables Import..."
terraform import aws_route_table.public "$PUBLIC_RT" || echo "⚠️  이미 import됨"
terraform import 'aws_route_table.private[0]' "$PRIVATE_RT" || echo "⚠️  이미 import됨"

echo ""
echo "✅ Import 완료!"
echo ""
echo "📝 다음 단계:"
echo "  1. terraform plan으로 변경사항 확인"
echo "  2. 예상치 못한 변경이 있다면 terraform.tfvars 수정"
echo "  3. terraform apply로 SSM Parameters 생성"
echo ""
