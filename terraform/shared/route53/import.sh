#!/bin/bash

# ============================================================================
# Route53 Hosted Zone Import Script - set-of.com
# ============================================================================
#
# 현재 운영 중인 Route53 Hosted Zone을 Terraform State로 import
#
# ============================================================================

set -e

echo "🚀 Route53 Hosted Zone Import 시작..."
echo ""

# ============================================================================
# RESOURCE IDS - 확인 필요
# ============================================================================
#
# ⚠️  주의: Hosted Zone ID를 확인하여 아래 값을 업데이트해야 합니다
#
# Hosted Zone ID 확인 방법:
#   aws route53 list-hosted-zones --query "HostedZones[?Name=='set-of.com.'].Id" --output text
#
# 또는 AWS Console에서:
#   Route53 > Hosted Zones > set-of.com > Hosted zone ID
# ============================================================================

ZONE_ID="Z104656329CL6XBYE8OIJ"
DOMAIN_NAME="set-of.com"

# Zone ID가 placeholder인지 확인
if [[ "$ZONE_ID" == "ZXXXXXXXXXXXXX" ]]; then
    echo "❌ 오류: Hosted Zone ID를 설정해야 합니다"
    echo ""
    echo "📝 Zone ID 확인 방법:"
    echo "  aws route53 list-hosted-zones --query \"HostedZones[?Name=='${DOMAIN_NAME}.'].Id\" --output text"
    echo ""
    echo "또는 AWS Console에서:"
    echo "  Route53 > Hosted Zones > ${DOMAIN_NAME} > Hosted zone ID"
    echo ""
    echo "확인 후 import.sh 파일의 ZONE_ID 변수를 업데이트하세요."
    exit 1
fi

# ============================================================================
# Import 실행
# ============================================================================

echo "📋 리소스 정보:"
echo "  Hosted Zone ID: $ZONE_ID"
echo "  Domain: $DOMAIN_NAME"
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
echo "2️⃣ Route53 Hosted Zone Import..."
terraform import aws_route53_zone.main "$ZONE_ID" || echo "⚠️  이미 import됨"

echo ""
echo "✅ Import 완료!"
echo ""
echo "📝 다음 단계:"
echo "  1. terraform plan으로 변경사항 확인"
echo "  2. terraform apply로 SSM Parameters 생성"
echo ""
echo "⚠️  주의사항:"
echo "  - Import 후에는 기존 DNS 레코드들이 Terraform 관리 대상이 아닙니다"
echo "  - 필요한 레코드들은 별도로 import하거나 Terraform 코드로 관리 필요"
echo "  - Name Server는 변경되지 않으므로 도메인 등록 업체 설정 변경 불필요"
echo ""
