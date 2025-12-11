#!/bin/bash
# ============================================================================
# RDS Schema and User Setup Script
# prod-shared-mysql 데이터베이스용 스키마/유저 생성 자동화 스크립트
# ============================================================================
#
# 사전 요구사항:
# - AWS CLI가 설치되어 있고 적절한 권한이 설정되어 있어야 함
# - mysql 클라이언트가 설치되어 있어야 함
# - Terraform apply가 먼저 실행되어 Secrets Manager에 비밀번호가 생성되어 있어야 함
#
# 사용법:
#   ./scripts/rds-setup-users.sh
#
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}RDS Schema/User Setup Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Configuration
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
RDS_ENDPOINT="${RDS_ENDPOINT:-}"
MASTER_SECRET_NAME="prod-shared-mysql-master-password"
SETOF_SECRET_NAME="prod-shared-mysql-setof-password"
AUTH_SECRET_NAME="prod-shared-mysql-auth-password"

# Get RDS endpoint from SSM if not provided
if [ -z "$RDS_ENDPOINT" ]; then
    echo -e "${YELLOW}RDS endpoint 조회 중...${NC}"
    RDS_ENDPOINT=$(aws ssm get-parameter \
        --name "/shared/rds/db-instance-address" \
        --query "Parameter.Value" \
        --output text \
        --region "$AWS_REGION" 2>/dev/null || echo "")

    if [ -z "$RDS_ENDPOINT" ]; then
        echo -e "${RED}Error: RDS endpoint를 찾을 수 없습니다.${NC}"
        echo "RDS_ENDPOINT 환경변수를 설정하거나 SSM Parameter가 존재하는지 확인하세요."
        exit 1
    fi
fi

echo -e "${GREEN}RDS Endpoint: ${RDS_ENDPOINT}${NC}"

# Get master credentials
echo -e "${YELLOW}Master credentials 조회 중...${NC}"
MASTER_CREDS=$(aws secretsmanager get-secret-value \
    --secret-id "$MASTER_SECRET_NAME" \
    --query "SecretString" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$MASTER_CREDS" ]; then
    echo -e "${RED}Error: Master credentials를 찾을 수 없습니다.${NC}"
    echo "Terraform apply가 실행되었는지 확인하세요."
    exit 1
fi

MASTER_USER=$(echo "$MASTER_CREDS" | jq -r '.username')
MASTER_PASS=$(echo "$MASTER_CREDS" | jq -r '.password')

# Get application user passwords
echo -e "${YELLOW}Application user credentials 조회 중...${NC}"

SETOF_CREDS=$(aws secretsmanager get-secret-value \
    --secret-id "$SETOF_SECRET_NAME" \
    --query "SecretString" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$SETOF_CREDS" ]; then
    echo -e "${RED}Error: setof credentials를 찾을 수 없습니다.${NC}"
    echo "Terraform apply가 실행되었는지 확인하세요."
    exit 1
fi

SETOF_PASS=$(echo "$SETOF_CREDS" | jq -r '.password')

AUTH_CREDS=$(aws secretsmanager get-secret-value \
    --secret-id "$AUTH_SECRET_NAME" \
    --query "SecretString" \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || echo "")

if [ -z "$AUTH_CREDS" ]; then
    echo -e "${RED}Error: auth credentials를 찾을 수 없습니다.${NC}"
    echo "Terraform apply가 실행되었는지 확인하세요."
    exit 1
fi

AUTH_PASS=$(echo "$AUTH_CREDS" | jq -r '.password')

echo -e "${GREEN}Credentials 조회 완료${NC}"

# Create SQL script with actual passwords
SQL_SCRIPT=$(cat <<EOF
-- setof 스키마 및 유저 생성
CREATE DATABASE IF NOT EXISTS setof
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'setof_user'@'%' IDENTIFIED BY '${SETOF_PASS}';
GRANT ALL PRIVILEGES ON setof.* TO 'setof_user'@'%';

-- auth 스키마 및 유저 생성
CREATE DATABASE IF NOT EXISTS auth
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'auth_user'@'%' IDENTIFIED BY '${AUTH_PASS}';
GRANT ALL PRIVILEGES ON auth.* TO 'auth_user'@'%';

-- 권한 적용
FLUSH PRIVILEGES;

-- 검증
SELECT 'Databases:' as '';
SHOW DATABASES LIKE 'setof';
SHOW DATABASES LIKE 'auth';
SELECT 'Users:' as '';
SELECT User, Host FROM mysql.user WHERE User IN ('setof_user', 'auth_user');
EOF
)

echo -e "${YELLOW}스키마 및 유저 생성 중...${NC}"

# Execute SQL
echo "$SQL_SCRIPT" | mysql -h "$RDS_ENDPOINT" -u "$MASTER_USER" -p"$MASTER_PASS" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ 스키마 및 유저 생성 완료!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "생성된 스키마:"
    echo -e "  - ${GREEN}setof${NC} (setof_user)"
    echo -e "  - ${GREEN}auth${NC} (auth_user)"
    echo ""
    echo -e "접속 정보는 AWS Secrets Manager에서 확인하세요:"
    echo -e "  - setof: ${SETOF_SECRET_NAME}"
    echo -e "  - auth: ${AUTH_SECRET_NAME}"
else
    echo -e "${RED}Error: SQL 실행 중 오류가 발생했습니다.${NC}"
    exit 1
fi
