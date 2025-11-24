#!/bin/bash

# ============================================================================
# ACM Certificate Import Script - *.set-of.com
# ============================================================================
#
# 현재 운영 중인 ACM 인증서를 Terraform State로 import
#
# ============================================================================

set -e

echo "🚀 ACM Certificate Import 시작..."
echo ""

# ============================================================================
# RESOURCE IDS - 확인된 실제 리소스 ARN
# ============================================================================

CERTIFICATE_ARN="arn:aws:acm:ap-northeast-2:646886795421:certificate/4241052f-dc09-4be1-8e4b-08902fce4729"
CERTIFICATE_DOMAIN="*.set-of.com"

# ============================================================================
# Import 실행
# ============================================================================

echo "📋 리소스 정보:"
echo "  Certificate ARN: $CERTIFICATE_ARN"
echo "  Domain: $CERTIFICATE_DOMAIN"
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
echo "2️⃣ ACM Certificate Import..."
terraform import aws_acm_certificate.main "$CERTIFICATE_ARN" || echo "⚠️  이미 import됨"

echo ""
echo "✅ Import 완료!"
echo ""
echo "📝 다음 단계:"
echo "  1. terraform plan으로 변경사항 확인"
echo "  2. terraform apply로 SSM Parameters 생성"
echo ""
echo "⚠️  주의사항:"
echo "  - Validation 관련 리소스는 import하지 않음 (이미 검증 완료)"
echo "  - Certificate는 read-only 속성이 많으므로 lifecycle ignore_changes 설정 필요"
echo ""
