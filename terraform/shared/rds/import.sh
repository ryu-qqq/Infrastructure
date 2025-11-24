#!/bin/bash

# ============================================================================
# RDS Import Script - Shared MySQL
# ============================================================================
#
# 현재 운영 중인 RDS (prod-shared-mysql)를 Terraform State로 import
#
# ============================================================================

set -e  # 에러 발생 시 즉시 중단

echo "🚀 RDS Import 시작..."
echo ""

# ============================================================================
# RESOURCE IDS - 확인된 실제 리소스 ID
# ============================================================================

DB_INSTANCE="prod-shared-mysql"
DB_SUBNET_GROUP="prod-shared-mysql-subnet-group"
DB_PARAMETER_GROUP="prod-shared-mysql-params"
SECURITY_GROUP="sg-0d9b6f65239b16b44"
MONITORING_ROLE="prod-shared-mysql-monitoring-role"

# ============================================================================
# Import 실행
# ============================================================================

echo "📋 리소스 ID 확인:"
echo "  DB Instance: $DB_INSTANCE"
echo "  DB Subnet Group: $DB_SUBNET_GROUP"
echo "  DB Parameter Group: $DB_PARAMETER_GROUP"
echo "  Security Group: $SECURITY_GROUP"
echo "  Monitoring Role: $MONITORING_ROLE"
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
echo "2️⃣ DB Instance Import..."
terraform import aws_db_instance.main "$DB_INSTANCE" || echo "⚠️  이미 import됨"

echo ""
echo "3️⃣ DB Subnet Group Import..."
terraform import aws_db_subnet_group.main "$DB_SUBNET_GROUP" || echo "⚠️  이미 import됨"

echo ""
echo "4️⃣ DB Parameter Group Import..."
terraform import aws_db_parameter_group.main "$DB_PARAMETER_GROUP" || echo "⚠️  이미 import됨"

echo ""
echo "5️⃣ Security Group Import..."
terraform import aws_security_group.main "$SECURITY_GROUP" || echo "⚠️  이미 import됨"

echo ""
echo "6️⃣ Monitoring IAM Role Import..."
terraform import 'aws_iam_role.monitoring[0]' "$MONITORING_ROLE" || echo "⚠️  이미 import됨"

echo ""
echo "✅ Import 완료!"
echo ""
echo "📝 다음 단계:"
echo "  1. terraform plan으로 변경사항 확인"
echo "  2. 예상치 못한 변경이 있다면 terraform.tfvars 또는 코드 수정"
echo "  3. terraform apply로 SSM Parameters 생성"
echo ""
echo "⚠️  주의사항:"
echo "  - Security Group Rules는 별도 import 필요할 수 있음"
echo "  - DB 비밀번호 관련 설정은 plan 결과 확인 후 조정"
echo ""
