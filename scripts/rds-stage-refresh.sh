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

set -e

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

TFVARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"

if [ "$DRY_RUN" = true ]; then
    log_warning "[DRY-RUN] terraform.tfvars 업데이트를 건너뜁니다."
else
    # Backup current tfvars
    cp "${TFVARS_FILE}" "${TFVARS_FILE}.backup"

    # Update restore settings
    sed -i.tmp 's/restore_from_snapshot = false/restore_from_snapshot = true/' "${TFVARS_FILE}"
    sed -i.tmp "s/snapshot_identifier   = null/snapshot_identifier   = \"${SNAPSHOT_ID}\"/" "${TFVARS_FILE}"
    rm -f "${TFVARS_FILE}.tmp"

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

    cd "${TERRAFORM_DIR}"

    # Target destroy only the RDS module
    terraform init -input=false
    terraform destroy -target=module.rds -auto-approve

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

# Step 5: Reset tfvars for normal operation
log_info "Step 5: Terraform 설정 복원 중..."

if [ "$DRY_RUN" = true ]; then
    log_warning "[DRY-RUN] terraform.tfvars 복원을 건너뜁니다."
else
    # Reset restore settings for future normal operations
    sed -i.tmp 's/restore_from_snapshot = true/restore_from_snapshot = false/' "${TFVARS_FILE}"
    sed -i.tmp "s/snapshot_identifier   = \"${SNAPSHOT_ID}\"/snapshot_identifier   = null/" "${TFVARS_FILE}"
    rm -f "${TFVARS_FILE}.tmp"

    log_success "terraform.tfvars 복원 완료"
fi

echo ""

# Step 6: Optional - Data masking reminder
log_warning "=============================================="
log_warning "  ⚠️  데이터 마스킹 확인"
log_warning "=============================================="
echo ""
echo "Production 데이터가 Stage에 복사되었습니다."
echo "민감한 데이터(이메일, 전화번호 등)가 있다면 마스킹이 필요합니다."
echo ""
echo "마스킹 예시 SQL:"
echo "  UPDATE users SET"
echo "    email = CONCAT('user', id, '@test.com'),"
echo "    phone = '010-0000-0000',"
echo "    name = CONCAT('테스트유저', id);"
echo ""

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
