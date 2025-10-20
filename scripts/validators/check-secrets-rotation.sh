#!/bin/bash

# ============================================================================
# Secrets Manager Rotation 검증 스크립트
# ============================================================================
# 
# 용도: RDS 및 기타 시크릿의 rotation 설정 상태를 검증합니다.
#
# 사용법:
#   ./check-secrets-rotation.sh [options]
#
# Options:
#   -r, --region REGION    AWS Region (기본값: ap-northeast-2)
#   -v, --verbose          상세 출력
#   -h, --help            도움말 표시
#
# 예시:
#   ./check-secrets-rotation.sh
#   ./check-secrets-rotation.sh --region us-east-1 --verbose
#
# ============================================================================

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 기본 설정
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
VERBOSE=false

# 함수: 사용법 표시
usage() {
    cat << EOF
사용법: $0 [OPTIONS]

Secrets Manager Rotation 설정을 검증합니다.

OPTIONS:
    -r, --region REGION     AWS Region (기본값: ap-northeast-2)
    -v, --verbose          상세 출력 활성화
    -h, --help            이 도움말 표시

예시:
    $0
    $0 --region us-east-1 --verbose

EOF
    exit 1
}

# 함수: 에러 메시지
error() {
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
}

# 함수: 성공 메시지
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 함수: 경고 메시지
warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
}

# 함수: 정보 메시지
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 함수: 상세 정보 (verbose 모드)
debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${NC}    $1${NC}"
    fi
}

# 명령행 인자 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "알 수 없는 옵션: $1"
            usage
            ;;
    esac
done

# AWS CLI 설치 확인
if ! command -v aws &> /dev/null; then
    error "AWS CLI가 설치되어 있지 않습니다."
    exit 1
fi

# AWS 인증 확인
if ! aws sts get-caller-identity &> /dev/null; then
    error "AWS 인증에 실패했습니다. AWS credentials를 확인하세요."
    exit 1
fi

echo "=================================================="
echo "  Secrets Manager Rotation 검증 시작"
echo "=================================================="
echo ""
info "Region: $AWS_REGION"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
info "Account ID: $ACCOUNT_ID"
echo ""

# ============================================================================
# 1. Secrets 목록 조회
# ============================================================================

echo "----------------------------------------"
echo "1. Secrets Manager 시크릿 목록 조회"
echo "----------------------------------------"

SECRETS=$(aws secretsmanager list-secrets \
    --region "$AWS_REGION" \
    --query 'SecretList[?contains(Name, `rds`) || contains(Name, `master`) || contains(Name, `password`)].{Name:Name,RotationEnabled:RotationEnabled}' \
    --output json 2>/dev/null)

if [ -z "$SECRETS" ] || [ "$SECRETS" = "[]" ]; then
    warning "RDS 관련 시크릿을 찾을 수 없습니다."
    echo ""
else
    SECRET_COUNT=$(echo "$SECRETS" | jq '. | length')
    success "총 $SECRET_COUNT개의 시크릿을 찾았습니다."
    echo ""
    
    echo "$SECRETS" | jq -r '.[] | "\(.Name) - Rotation: \(if .RotationEnabled then "✅ Enabled" else "❌ Disabled" end)"'
    echo ""
fi

# ============================================================================
# 2. 각 시크릿의 상세 정보 확인
# ============================================================================

echo "----------------------------------------"
echo "2. 시크릿 상세 정보 확인"
echo "----------------------------------------"

ROTATION_ENABLED_COUNT=0
ROTATION_DISABLED_COUNT=0
TOTAL_CHECKED=0

while IFS= read -r SECRET_NAME; do
    if [ -z "$SECRET_NAME" ]; then
        continue
    fi
    
    TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
    
    echo ""
    info "시크릿: $SECRET_NAME"
    
    SECRET_INFO=$(aws secretsmanager describe-secret \
        --secret-id "$SECRET_NAME" \
        --region "$AWS_REGION" \
        --output json 2>/dev/null)
    
    if [ -z "$SECRET_INFO" ]; then
        error "시크릿 정보를 가져올 수 없습니다: $SECRET_NAME"
        continue
    fi
    
    ROTATION_ENABLED=$(echo "$SECRET_INFO" | jq -r '.RotationEnabled // false')
    
    if [ "$ROTATION_ENABLED" = "true" ]; then
        success "  Rotation: 활성화"
        ROTATION_ENABLED_COUNT=$((ROTATION_ENABLED_COUNT + 1))
        
        ROTATION_LAMBDA=$(echo "$SECRET_INFO" | jq -r '.RotationLambdaARN // "N/A"')
        ROTATION_DAYS=$(echo "$SECRET_INFO" | jq -r '.RotationRules.AutomaticallyAfterDays // "N/A"')
        LAST_ROTATED=$(echo "$SECRET_INFO" | jq -r '.LastRotatedDate // "없음"')
        NEXT_ROTATION=$(echo "$SECRET_INFO" | jq -r '.NextRotationDate // "예정 없음"')
        
        debug "Lambda ARN: $ROTATION_LAMBDA"
        debug "Rotation 주기: $ROTATION_DAYS일"
        debug "마지막 Rotation: $LAST_ROTATED"
        debug "다음 Rotation: $NEXT_ROTATION"
        
        # Rotation 주기 검증
        if [ "$ROTATION_DAYS" != "N/A" ]; then
            if [ "$ROTATION_DAYS" -gt 90 ]; then
                warning "  Rotation 주기가 90일을 초과합니다: ${ROTATION_DAYS}일"
            elif [ "$ROTATION_DAYS" -lt 30 ]; then
                warning "  Rotation 주기가 30일 미만입니다: ${ROTATION_DAYS}일"
            else
                success "  Rotation 주기: ${ROTATION_DAYS}일 (권장 범위)"
            fi
        fi
        
    else
        error "  Rotation: 비활성화"
        ROTATION_DISABLED_COUNT=$((ROTATION_DISABLED_COUNT + 1))
        warning "  이 시크릿은 자동 rotation이 설정되지 않았습니다!"
    fi
    
done < <(echo "$SECRETS" | jq -r '.[].Name')

# ============================================================================
# 3. Lambda 함수 확인
# ============================================================================

echo ""
echo "----------------------------------------"
echo "3. Rotation Lambda 함수 확인"
echo "----------------------------------------"

LAMBDA_NAME="secrets-manager-rotation"

if aws lambda get-function --function-name "$LAMBDA_NAME" --region "$AWS_REGION" &> /dev/null; then
    success "Lambda 함수 존재: $LAMBDA_NAME"
    
    LAMBDA_INFO=$(aws lambda get-function-configuration \
        --function-name "$LAMBDA_NAME" \
        --region "$AWS_REGION" \
        --output json)
    
    LAMBDA_RUNTIME=$(echo "$LAMBDA_INFO" | jq -r '.Runtime')
    LAMBDA_TIMEOUT=$(echo "$LAMBDA_INFO" | jq -r '.Timeout')
    LAMBDA_VPC=$(echo "$LAMBDA_INFO" | jq -r '.VpcConfig.VpcId // "N/A"')
    
    debug "Runtime: $LAMBDA_RUNTIME"
    debug "Timeout: ${LAMBDA_TIMEOUT}초"
    debug "VPC ID: $LAMBDA_VPC"
    
    # VPC 설정 확인
    if [ "$LAMBDA_VPC" != "N/A" ] && [ "$LAMBDA_VPC" != "null" ]; then
        success "  Lambda가 VPC에 배포되어 있습니다."
        SUBNET_COUNT=$(echo "$LAMBDA_INFO" | jq '.VpcConfig.SubnetIds | length')
        SG_COUNT=$(echo "$LAMBDA_INFO" | jq '.VpcConfig.SecurityGroupIds | length')
        debug "Subnet 수: $SUBNET_COUNT"
        debug "Security Group 수: $SG_COUNT"
    else
        warning "  Lambda가 VPC에 배포되지 않았습니다. RDS 접근 불가능할 수 있습니다."
    fi
    
    # Timeout 확인
    if [ "$LAMBDA_TIMEOUT" -lt 60 ]; then
        warning "  Timeout이 60초 미만입니다: ${LAMBDA_TIMEOUT}초"
        warning "  Rotation 작업이 실패할 수 있습니다."
    fi
    
else
    error "Lambda 함수를 찾을 수 없습니다: $LAMBDA_NAME"
    error "Rotation이 작동하지 않을 수 있습니다!"
fi

# ============================================================================
# 4. CloudWatch 알람 확인
# ============================================================================

echo ""
echo "----------------------------------------"
echo "4. CloudWatch 알람 확인"
echo "----------------------------------------"

ALARM_NAME="secrets-manager-rotation-failures"

if aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --region "$AWS_REGION" \
    --output json 2>/dev/null | jq -e '.MetricAlarms | length > 0' &> /dev/null; then
    
    success "CloudWatch 알람 존재: $ALARM_NAME"
    
    ALARM_INFO=$(aws cloudwatch describe-alarms \
        --alarm-names "$ALARM_NAME" \
        --region "$AWS_REGION" \
        --output json | jq -r '.MetricAlarms[0]')
    
    ALARM_STATE=$(echo "$ALARM_INFO" | jq -r '.StateValue')
    debug "알람 상태: $ALARM_STATE"
    
    if [ "$ALARM_STATE" = "ALARM" ]; then
        error "  알람이 발생 중입니다! Rotation 실패를 확인하세요."
    elif [ "$ALARM_STATE" = "OK" ]; then
        success "  알람 상태: 정상"
    else
        info "  알람 상태: $ALARM_STATE"
    fi
    
else
    warning "CloudWatch 알람을 찾을 수 없습니다: $ALARM_NAME"
    warning "Rotation 실패 시 알림을 받을 수 없습니다."
fi

# ============================================================================
# 5. 최근 Rotation 로그 확인 (optional)
# ============================================================================

if [ "$VERBOSE" = true ]; then
    echo ""
    echo "----------------------------------------"
    echo "5. 최근 Rotation 로그 확인"
    echo "----------------------------------------"
    
    LOG_GROUP="/aws/lambda/secrets-manager-rotation"
    
    if aws logs describe-log-groups \
        --log-group-name-prefix "$LOG_GROUP" \
        --region "$AWS_REGION" \
        --output json 2>/dev/null | jq -e '.logGroups | length > 0' &> /dev/null; then
        
        success "Lambda 로그 그룹 존재: $LOG_GROUP"
        
        # 최근 1시간 이내 에러 로그 검색
        START_TIME=$(($(date +%s) - 3600))000  # 1시간 전 (밀리초)
        END_TIME=$(date +%s)000  # 현재 시간 (밀리초)
        
        ERROR_LOGS=$(aws logs filter-log-events \
            --log-group-name "$LOG_GROUP" \
            --start-time "$START_TIME" \
            --end-time "$END_TIME" \
            --filter-pattern "ERROR" \
            --region "$AWS_REGION" \
            --output json 2>/dev/null | jq -r '.events | length')
        
        if [ "$ERROR_LOGS" -gt 0 ]; then
            warning "  최근 1시간 이내 에러 로그: ${ERROR_LOGS}건"
            warning "  로그를 확인하세요: aws logs tail $LOG_GROUP --follow"
        else
            success "  최근 1시간 이내 에러 로그: 없음"
        fi
        
    else
        warning "Lambda 로그 그룹을 찾을 수 없습니다: $LOG_GROUP"
    fi
fi

# ============================================================================
# 6. 요약 및 권장사항
# ============================================================================

echo ""
echo "=================================================="
echo "  검증 결과 요약"
echo "=================================================="
echo ""

if [ "$TOTAL_CHECKED" -gt 0 ]; then
    echo "총 시크릿 수: $TOTAL_CHECKED"
    echo "Rotation 활성화: $ROTATION_ENABLED_COUNT"
    echo "Rotation 비활성화: $ROTATION_DISABLED_COUNT"
    echo ""
fi

# 종합 상태 판정
ISSUES_FOUND=0

if [ "$ROTATION_DISABLED_COUNT" -gt 0 ]; then
    error "일부 시크릿에 Rotation이 비활성화되어 있습니다."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if ! aws lambda get-function --function-name "$LAMBDA_NAME" --region "$AWS_REGION" &> /dev/null; then
    error "Rotation Lambda 함수가 없습니다."
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

if ! aws cloudwatch describe-alarms --alarm-names "$ALARM_NAME" --region "$AWS_REGION" --output json 2>/dev/null | jq -e '.MetricAlarms | length > 0' &> /dev/null; then
    warning "CloudWatch 알람이 설정되지 않았습니다."
fi

echo ""
if [ "$ISSUES_FOUND" -eq 0 ]; then
    success "=== 모든 검증 항목 통과 ==="
    echo ""
    info "다음 단계:"
    echo "  1. docs/governance/SECRETS_ROTATION_CHECKLIST.md 참고"
    echo "  2. 실제 Rotation 테스트 수행"
    echo "  3. 애플리케이션 재시도 로직 구현 확인"
    exit 0
else
    error "=== $ISSUES_FOUND개의 문제 발견 ==="
    echo ""
    info "조치 필요:"
    echo "  1. docs/governance/SECRETS_ROTATION_CURRENT_STATUS.md 확인"
    echo "  2. terraform/rds/terraform.tfvars에서 enable_secrets_rotation = true 설정"
    echo "  3. terraform apply 실행"
    exit 1
fi
