#!/bin/bash
# =============================================================================
# Stage RDS Monthly Refresh Script
# =============================================================================
# 이 스크립트는 prod RDS의 스냅샷을 생성하고 stage RDS를 새 스냅샷으로 리프레시합니다.
#
# 사용법:
#   ./scripts/rds-stage-refresh.sh [--skip-snapshot] [--snapshot-id <id>]
#
# 옵션:
#   --skip-snapshot    기존 스냅샷 사용 (새 스냅샷 생성 건너뜀)
#   --snapshot-id      특정 스냅샷 ID 지정
#   --dry-run          실제 실행 없이 계획만 표시
#   --no-confirm       확인 프롬프트 건너뜀
#
# 주의사항:
#   - Stage RDS가 삭제되고 재생성됩니다
#   - 기존 테스트 데이터는 모두 손실됩니다
#   - 팀에 사전 공지 후 실행하세요
# =============================================================================

set -euo pipefail

# =============================================================================
# Cleanup and Error Handling
# =============================================================================
TFVARS_FILE=""
CLEANUP_NEEDED=false

cleanup() {
    if [ "$CLEANUP_NEEDED" = true ] && [ -n "$TFVARS_FILE" ] && [ -f "${TFVARS_FILE}.backup" ]; then
        echo -e "\033[1;33m[WARNING]\033[0m 스크립트가 중단됨. terraform.tfvars 복원 중..."
        mv "${TFVARS_FILE}.backup" "${TFVARS_FILE}"
        echo -e "\033[0;32m[SUCCESS]\033[0m terraform.tfvars 복원 완료"
    fi
    # sed 임시 파일 정리
    if [ -n "$TFVARS_FILE" ]; then
        rm -f "${TFVARS_FILE}.tmp"
    fi
}

trap cleanup EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROD_DB_IDENTIFIER="prod-shared-mysql"
STAGE_DB_IDENTIFIER="staging-shared-mysql"
AWS_REGION="ap-northeast-2"
TERRAFORM_DIR="terraform/environments/stage/rds"
SNAPSHOT_PREFIX="stage-refresh"

# Parse arguments
SKIP_SNAPSHOT=false
SNAPSHOT_ID=""
DRY_RUN=false
NO_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-snapshot)
            SKIP_SNAPSHOT=true
            shift
            ;;
        --snapshot-id)
            SNAPSHOT_ID="$2"
            SKIP_SNAPSHOT=true
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-confirm)
            NO_CONFIRM=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--skip-snapshot] [--snapshot-id <id>] [--dry-run] [--no-confirm]"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm() {
    if [ "$NO_CONFIRM" = true ]; then
        return 0
    fi

    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "작업이 취소되었습니다."
        exit 1
    fi
}

# =============================================================================
# Main Script
# =============================================================================

echo "=============================================="
echo "  Stage RDS Monthly Refresh Script"
echo "=============================================="
echo ""

# Check prerequisites
log_info "사전 요구사항 확인 중..."

if ! command -v aws &> /dev/null; then
    log_error "AWS CLI가 설치되어 있지 않습니다."
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    log_error "Terraform이 설치되어 있지 않습니다."
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS 자격 증명이 구성되지 않았습니다."
    exit 1
fi

log_success "사전 요구사항 확인 완료"
echo ""

# Step 1: Create snapshot from prod (if not skipping)
if [ "$SKIP_SNAPSHOT" = false ]; then
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    SNAPSHOT_ID="${SNAPSHOT_PREFIX}-${TIMESTAMP}"

    log_info "Step 1: Prod RDS 스냅샷 생성 중..."
    log_info "  - Source DB: ${PROD_DB_IDENTIFIER}"
    log_info "  - Snapshot ID: ${SNAPSHOT_ID}"
    echo ""

    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY-RUN] 스냅샷 생성을 건너뜁니다."
    else
        confirm

        aws rds create-db-snapshot \
            --db-instance-identifier "${PROD_DB_IDENTIFIER}" \
            --db-snapshot-identifier "${SNAPSHOT_ID}" \
            --region "${AWS_REGION}" \
            --tags Key=Purpose,Value=stage-refresh Key=CreatedBy,Value=refresh-script

        log_info "스냅샷 생성이 시작되었습니다. 완료될 때까지 대기 중..."

        aws rds wait db-snapshot-available \
            --db-snapshot-identifier "${SNAPSHOT_ID}" \
            --region "${AWS_REGION}"

        log_success "스냅샷 생성 완료: ${SNAPSHOT_ID}"
    fi
else
    if [ -z "$SNAPSHOT_ID" ]; then
        # Get latest snapshot
        log_info "최신 스냅샷 조회 중..."
        SNAPSHOT_ID=$(aws rds describe-db-snapshots \
            --db-instance-identifier "${PROD_DB_IDENTIFIER}" \
            --snapshot-type manual \
            --query 'DBSnapshots | sort_by(@, &SnapshotCreateTime) | [-1].DBSnapshotIdentifier' \
            --output text \
            --region "${AWS_REGION}")

        if [ "$SNAPSHOT_ID" = "None" ] || [ -z "$SNAPSHOT_ID" ]; then
            log_error "사용 가능한 스냅샷이 없습니다."
            exit 1
        fi
    fi
    log_info "Step 1: 기존 스냅샷 사용: ${SNAPSHOT_ID}"
fi

echo ""

# Step 2: Update terraform.tfvars for snapshot restore
log_info "Step 2: Terraform 설정 업데이트 중..."

TFVARS_FILE="${TERRAFORM_DIR}/terraform.auto.tfvars"

if [ "$DRY_RUN" = true ]; then
    log_warning "[DRY-RUN] terraform.tfvars 업데이트를 건너뜁니다."
else
    # Backup current tfvars
    cp "${TFVARS_FILE}" "${TFVARS_FILE}.backup"
    CLEANUP_NEEDED=true

    # Update restore settings (유연한 정규식으로 공백 변화에 대응)
    sed -i.tmp 's/restore_from_snapshot[[:space:]]*=[[:space:]]*false/restore_from_snapshot = true/' "${TFVARS_FILE}"
    sed -i.tmp "s/snapshot_identifier[[:space:]]*=[[:space:]]*null/snapshot_identifier   = \"${SNAPSHOT_ID}\"/" "${TFVARS_FILE}"
    rm -f "${TFVARS_FILE}.tmp"

    # 변경 적용 검증
    if ! grep -q "restore_from_snapshot = true" "${TFVARS_FILE}"; then
        log_error "restore_from_snapshot 설정 업데이트 실패"
        exit 1
    fi
    if ! grep -q "snapshot_identifier.*${SNAPSHOT_ID}" "${TFVARS_FILE}"; then
        log_error "snapshot_identifier 설정 업데이트 실패"
        exit 1
    fi

    log_success "terraform.tfvars 업데이트 완료"
fi

echo ""

# Step 3: Destroy existing stage RDS
log_info "Step 3: 기존 Stage RDS 삭제 중..."
log_warning "⚠️  이 작업은 기존 stage 데이터베이스를 삭제합니다!"
echo ""

if [ "$DRY_RUN" = true ]; then
    log_warning "[DRY-RUN] Stage RDS 삭제를 건너뜁니다."
else
    confirm

    # 디렉토리 검증
    if [ ! -d "${TERRAFORM_DIR}" ]; then
        log_error "Terraform 디렉토리가 존재하지 않습니다: ${TERRAFORM_DIR}"
        exit 1
    fi

    if [ ! -f "${TERRAFORM_DIR}/main.tf" ]; then
        log_error "유효한 Terraform 디렉토리가 아닙니다: ${TERRAFORM_DIR}"
        exit 1
    fi

    cd "${TERRAFORM_DIR}"

    # Backend 재초기화 (상태 불일치 방지)
    terraform init -input=false -reconfigure

    # State 리프레시 (현재 인프라 상태 동기화)
    log_info "Terraform state 리프레시 중..."
    terraform refresh

    # Target destroy only the RDS module
    terraform destroy -target=module.rds -auto-approve

    # 삭제 검증
    if terraform state list 2>/dev/null | grep -q "module.rds"; then
        log_error "RDS 모듈 삭제 검증 실패 - state에 여전히 존재합니다"
        exit 1
    fi

    cd - > /dev/null

    log_success "기존 Stage RDS 삭제 완료"
fi

echo ""

# Step 4: Recreate stage RDS from snapshot
log_info "Step 4: 스냅샷에서 Stage RDS 재생성 중..."
log_info "  - Snapshot: ${SNAPSHOT_ID}"
echo ""

if [ "$DRY_RUN" = true ]; then
    log_warning "[DRY-RUN] Stage RDS 생성을 건너뜁니다."
else
    cd "${TERRAFORM_DIR}"

    terraform apply -auto-approve

    cd - > /dev/null

    log_success "Stage RDS 재생성 완료"
fi

echo ""

# Step 4.5: Password Reset and Secrets Manager Sync
log_info "Step 4.5: 암호 재설정 및 Secrets Manager 동기화 중..."

sync_db_password() {
    local new_password
    local db_identifier="${STAGE_DB_IDENTIFIER}"
    local secret_name="staging-shared-mysql-master-password"

    log_info "스냅샷 복원 후 DB 암호 재설정 시작..."

    # 새 암호 생성 (32자, 특수문자 포함)
    new_password=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)

    if [ -z "$new_password" ]; then
        log_error "새 암호 생성 실패"
        return 1
    fi

    log_info "RDS 마스터 암호 변경 중..."
    if ! aws rds modify-db-instance \
        --db-instance-identifier "${db_identifier}" \
        --master-user-password "${new_password}" \
        --apply-immediately \
        --region "${AWS_REGION}" > /dev/null 2>&1; then
        log_error "RDS 암호 변경 실패"
        return 1
    fi

    log_info "RDS 암호 변경 대기 중... (최대 5분)"
    sleep 30  # 변경 적용 대기

    # Secrets Manager 업데이트
    log_info "Secrets Manager 시크릿 업데이트 중..."

    # 현재 시크릿 값 조회
    local current_secret
    current_secret=$(aws secretsmanager get-secret-value \
        --secret-id "${secret_name}" \
        --query 'SecretString' \
        --output text \
        --region "${AWS_REGION}" 2>/dev/null || echo "{}")

    if [ "$current_secret" = "{}" ]; then
        log_warning "기존 시크릿을 찾을 수 없습니다. 새로 생성됩니다."
    fi

    # 시크릿 업데이트 (password 필드만 변경, note 업데이트)
    local updated_secret
    updated_secret=$(echo "$current_secret" | jq --arg pwd "$new_password" \
        '.password = $pwd | .note = "스냅샷 복원 후 자동 암호 재설정됨"')

    if ! aws secretsmanager update-secret \
        --secret-id "${secret_name}" \
        --secret-string "${updated_secret}" \
        --region "${AWS_REGION}" > /dev/null 2>&1; then
        log_error "Secrets Manager 업데이트 실패"
        log_warning "수동으로 암호를 업데이트해주세요:"
        echo "  aws secretsmanager update-secret --secret-id ${secret_name} --secret-string '{\"password\": \"${new_password}\"}'"
        return 1
    fi

    log_success "암호 동기화 완료"
    log_info "새 암호가 RDS와 Secrets Manager에 동기화되었습니다."

    return 0
}

if [ "$DRY_RUN" = true ]; then
    log_warning "[DRY-RUN] 암호 동기화를 건너뜁니다."
else
    log_warning "⚠️  스냅샷 복원 시 프로덕션 암호가 상속됩니다."
    log_warning "⚠️  보안을 위해 새 암호로 재설정합니다."
    echo ""

    # jq 설치 확인
    if ! command -v jq &> /dev/null; then
        log_warning "jq가 설치되어 있지 않습니다."
        log_warning "암호 동기화를 수동으로 수행해주세요."
        echo ""
        echo "수동 암호 재설정 명령어:"
        echo "  1. 새 암호 생성: NEW_PWD=\$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)"
        echo "  2. RDS 암호 변경: aws rds modify-db-instance --db-instance-identifier ${STAGE_DB_IDENTIFIER} --master-user-password \"\$NEW_PWD\" --apply-immediately"
        echo "  3. Secrets Manager 업데이트: aws secretsmanager update-secret --secret-id staging-shared-mysql-master-password --secret-string '{\"password\": \"\$NEW_PWD\"}'"
    else
        if ! sync_db_password; then
            log_warning "자동 암호 동기화 실패. 위 명령어로 수동 설정 필요."
        fi
    fi
fi

echo ""

# Step 5: Reset tfvars for normal operation
log_info "Step 5: Terraform 설정 복원 중..."

if [ "$DRY_RUN" = true ]; then
    log_warning "[DRY-RUN] terraform.tfvars 복원을 건너뜁니다."
else
    # Reset restore settings for future normal operations (유연한 정규식)
    sed -i.tmp 's/restore_from_snapshot[[:space:]]*=[[:space:]]*true/restore_from_snapshot = false/' "${TFVARS_FILE}"
    sed -i.tmp "s/snapshot_identifier[[:space:]]*=[[:space:]]*\"${SNAPSHOT_ID}\"/snapshot_identifier   = null/" "${TFVARS_FILE}"
    rm -f "${TFVARS_FILE}.tmp"

    # 성공적으로 완료되었으므로 백업 파일 제거 및 cleanup 플래그 해제
    rm -f "${TFVARS_FILE}.backup"
    CLEANUP_NEEDED=false

    log_success "terraform.tfvars 복원 완료"
fi

echo ""

# Step 6: Automated Data Masking (GDPR/CCPA 컴플라이언스)
log_info "Step 6: 데이터 마스킹 처리 중..."

# 마스킹 대상 테이블/컬럼 설정 파일 경로
MASKING_CONFIG="${TERRAFORM_DIR}/../../../configs/data-masking-config.json"

run_data_masking() {
    local db_endpoint=$1
    local db_user=$2
    local db_name=$3

    log_info "PII 데이터 마스킹 시작..."

    # Secrets Manager에서 DB 자격 증명 조회
    local secret_arn
    secret_arn=$(aws secretsmanager list-secrets \
        --filters Key=name,Values=staging-shared-mysql-master-password \
        --query 'SecretList[0].ARN' \
        --output text \
        --region "${AWS_REGION}" 2>/dev/null || echo "")

    if [ -z "$secret_arn" ] || [ "$secret_arn" = "None" ]; then
        log_warning "Secrets Manager에서 자격 증명을 찾을 수 없습니다."
        log_warning "데이터 마스킹을 수동으로 실행해주세요."
        return 1
    fi

    log_info "마스킹 SQL 실행 중..."
    # Note: 실제 마스킹은 DB 연결이 필요하므로, 여기서는 마스킹 스크립트 생성
    cat > "/tmp/stage-data-masking.sql" << 'MASKING_SQL'
-- Stage 환경 PII 데이터 마스킹 스크립트
-- GDPR/CCPA 컴플라이언스를 위해 프로덕션 데이터 복사 후 실행 필수

-- 사용자 이메일 마스킹
UPDATE users SET email = CONCAT('masked_user_', id, '@staging.local')
WHERE email NOT LIKE '%@staging.local';

-- 전화번호 마스킹
UPDATE users SET phone = CONCAT('010-0000-', LPAD(id % 10000, 4, '0'))
WHERE phone IS NOT NULL AND phone NOT LIKE '010-0000-%';

-- 이름 마스킹
UPDATE users SET name = CONCAT('테스트사용자_', id)
WHERE name IS NOT NULL AND name NOT LIKE '테스트사용자_%';

-- 주소 마스킹
UPDATE addresses SET
    address_line1 = CONCAT('테스트주소 ', id, '번지'),
    address_line2 = NULL,
    postal_code = '00000'
WHERE address_line1 NOT LIKE '테스트주소%';

-- 결제 정보 마스킹 (카드 번호 등)
UPDATE payment_methods SET
    card_last_four = '0000',
    card_holder_name = '테스트홀더'
WHERE card_last_four != '0000';

-- 마스킹 완료 로그
INSERT INTO audit_log (action, description, created_at)
VALUES ('DATA_MASKING', 'Stage 환경 PII 데이터 마스킹 완료', NOW());

SELECT 'PII 데이터 마스킹 완료' AS result;
MASKING_SQL

    log_success "마스킹 SQL 스크립트 생성: /tmp/stage-data-masking.sql"
    echo ""
    log_warning "⚠️  다음 명령어로 마스킹을 실행해주세요:"
    echo "    mysql -h <db-endpoint> -u <username> -p <database> < /tmp/stage-data-masking.sql"
    echo ""

    return 0
}

verify_data_masking() {
    log_info "데이터 마스킹 검증은 수동으로 수행해주세요."
    echo ""
    echo "검증 쿼리 예시:"
    echo "  -- 마스킹되지 않은 이메일 확인"
    echo "  SELECT COUNT(*) FROM users WHERE email NOT LIKE '%@staging.local';"
    echo ""
    echo "  -- 마스킹되지 않은 전화번호 확인"
    echo "  SELECT COUNT(*) FROM users WHERE phone NOT LIKE '010-0000-%';"
    echo ""
}

if [ "$DRY_RUN" = true ]; then
    log_warning "[DRY-RUN] 데이터 마스킹을 건너뜁니다."
else
    log_warning "=============================================="
    log_warning "  ⚠️  GDPR/CCPA 컴플라이언스: PII 마스킹 필수"
    log_warning "=============================================="
    echo ""
    echo "Production 데이터가 Stage에 복사되었습니다."
    echo "개인정보(이메일, 전화번호, 이름, 주소 등)는 반드시 마스킹해야 합니다."
    echo ""

    # 마스킹 스크립트 생성
    run_data_masking "" "" ""

    # 검증 안내
    verify_data_masking
fi

# Summary
echo "=============================================="
echo "  🎉 Stage RDS 리프레시 완료"
echo "=============================================="
echo ""
echo "  - Source Snapshot: ${SNAPSHOT_ID}"
echo "  - Target DB: ${STAGE_DB_IDENTIFIER}"
echo "  - Region: ${AWS_REGION}"
echo ""

if [ "$DRY_RUN" = true ]; then
    log_warning "이것은 DRY-RUN이었습니다. 실제 변경은 없습니다."
fi

log_success "작업 완료!"
