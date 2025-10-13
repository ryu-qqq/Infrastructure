#!/bin/bash

# ============================================
# Atlantis AssumeRole 테스트 스크립트
# TASK 1-2: IAM AssumeRole 권한 구조 검증
# ============================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 함수: 에러 메시지 출력
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 함수: 성공 메시지 출력
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 함수: 정보 메시지 출력
info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# 함수: AssumeRole 테스트
test_assume_role() {
    local ENV=$1
    local ROLE_ARN=$2

    info "Testing AssumeRole for ${ENV} environment..."
    info "Role ARN: ${ROLE_ARN}"

    # AssumeRole 실행
    CREDENTIALS=$(aws sts assume-role \
        --role-arn "${ROLE_ARN}" \
        --role-session-name "atlantis-test-${ENV}-$(date +%s)" \
        --duration-seconds 900 \
        --output json 2>&1)

    if [ $? -ne 0 ]; then
        error "Failed to assume role for ${ENV}: ${CREDENTIALS}"
    fi

    # 자격 증명 추출
    export AWS_ACCESS_KEY_ID=$(echo "${CREDENTIALS}" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "${CREDENTIALS}" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "${CREDENTIALS}" | jq -r '.Credentials.SessionToken')

    if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ "${AWS_ACCESS_KEY_ID}" == "null" ]; then
        error "Failed to extract credentials for ${ENV}"
    fi

    # Assumed Role 확인
    IDENTITY=$(aws sts get-caller-identity --output json 2>&1)
    if [ $? -ne 0 ]; then
        error "Failed to verify identity for ${ENV}: ${IDENTITY}"
    fi

    ASSUMED_ROLE_ARN=$(echo "${IDENTITY}" | jq -r '.Arn')
    info "Successfully assumed role: ${ASSUMED_ROLE_ARN}"

    # 기본 권한 테스트 (읽기 전용)
    info "Testing basic permissions..."

    # ECS 권한 테스트
    aws ecs describe-clusters --clusters test-cluster --region ap-northeast-2 >/dev/null 2>&1
    if [ $? -eq 0 ] || [ $? -eq 254 ]; then
        success "ECS describe permission: OK"
    else
        error "ECS describe permission: FAILED"
    fi

    # RDS 권한 테스트
    aws rds describe-db-instances --region ap-northeast-2 >/dev/null 2>&1
    if [ $? -eq 0 ] || [ $? -eq 254 ]; then
        success "RDS describe permission: OK"
    else
        error "RDS describe permission: FAILED"
    fi

    # VPC 권한 테스트
    aws ec2 describe-vpcs --region ap-northeast-2 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        success "VPC describe permission: OK"
    else
        error "VPC describe permission: FAILED"
    fi

    # 환경 변수 초기화
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN

    success "All tests passed for ${ENV} environment!"
    echo ""
}

# ============================================
# 메인 실행
# ============================================

info "Starting Atlantis AssumeRole Test Script"
echo ""

# Terraform output에서 Role ARN 가져오기
cd "$(dirname "$0")"

# Terraform이 초기화되어 있는지 확인
if [ ! -d ".terraform" ]; then
    info "Terraform not initialized. Running terraform init..."
    terraform init
fi

# Terraform output 가져오기
info "Retrieving Role ARNs from Terraform output..."
DEV_ROLE_ARN=$(terraform output -raw atlantis_target_dev_role_arn 2>/dev/null)
STG_ROLE_ARN=$(terraform output -raw atlantis_target_stg_role_arn 2>/dev/null)
PROD_ROLE_ARN=$(terraform output -raw atlantis_target_prod_role_arn 2>/dev/null)

if [ -z "${DEV_ROLE_ARN}" ] || [ "${DEV_ROLE_ARN}" == "null" ]; then
    error "Failed to retrieve Role ARNs. Please run 'terraform apply' first."
fi

# 각 환경별 AssumeRole 테스트
test_assume_role "dev" "${DEV_ROLE_ARN}"
test_assume_role "stg" "${STG_ROLE_ARN}"
test_assume_role "prod" "${PROD_ROLE_ARN}"

success "All AssumeRole tests completed successfully!"
info "Atlantis can now assume roles in all environments (dev/stg/prod)"
