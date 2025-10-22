#!/bin/bash
# check-terraform-docs.sh
# Terraform 문서 완성도 검증 스크립트
#
# 사용법:
#   ./scripts/check-terraform-docs.sh                    # 모든 패키지 검증
#   ./scripts/check-terraform-docs.sh terraform/rds      # 특정 패키지만 검증

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 에러 카운터
TOTAL_ERRORS=0
TOTAL_WARNINGS=0

# 필수 섹션 목록 (각 섹션은 여러 변형을 가질 수 있음)
# 형식: "섹션명|변형1|변형2|변형3"
REQUIRED_SECTIONS=(
    "개요|Overview|About"
    "사용 방법|Usage|Quick Start|Getting Started|배포 가이드|Deployment|How to Use"
    "Variables|Input Variables|Inputs|Configuration"
    "Outputs|Output Values|Return Values"
)

# 권장 섹션 목록
RECOMMENDED_SECTIONS=(
    "보안 고려사항"
    "Security Considerations"
    "Troubleshooting"
    "예제"
    "Examples"
)

# 로그 함수
log_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
    ((TOTAL_ERRORS++))
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
    ((TOTAL_WARNINGS++))
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# README 파일 검증
check_readme() {
    local dir=$1
    local readme="$dir/README.md"

    echo ""
    echo "=================================================="
    log_info "검증 중: $dir"
    echo "=================================================="

    # README.md 파일 존재 확인
    if [[ ! -f "$readme" ]]; then
        log_error "README.md 파일이 없습니다: $dir"
        return 1
    fi
    log_success "README.md 파일 존재"

    # 파일 크기 확인 (최소 1KB)
    local file_size=$(wc -c < "$readme")
    if [[ $file_size -lt 1000 ]]; then
        log_warning "README.md가 너무 짧습니다 (${file_size} bytes < 1000 bytes)"
    else
        log_success "README.md 크기 적절 (${file_size} bytes)"
    fi

    # 필수 섹션 확인
    for section_variants in "${REQUIRED_SECTIONS[@]}"; do
        # 파이프로 구분된 변형들을 배열로 분리
        IFS='|' read -ra variants <<< "$section_variants"
        primary_name="${variants[0]}"

        # 변형 중 하나라도 존재하는지 확인
        section_found=false
        found_variant=""
        for variant in "${variants[@]}"; do
            if grep -qi "^##.*${variant}" "$readme"; then
                section_found=true
                found_variant="$variant"
                break
            fi
        done

        if [[ "$section_found" == true ]]; then
            log_success "필수 섹션 존재: $primary_name (발견: $found_variant)"
        else
            log_error "필수 섹션 누락: $primary_name (변형: ${variants[*]})"
        fi
    done

    # 권장 섹션 확인
    for section in "${RECOMMENDED_SECTIONS[@]}"; do
        if grep -qi "^##.*${section}" "$readme"; then
            log_success "권장 섹션 존재: $section"
        else
            log_warning "권장 섹션 누락: $section"
        fi
    done

    # Last Updated 날짜 확인
    if grep -q "Last Updated" "$readme"; then
        local last_updated=$(grep "Last Updated" "$readme" | head -1)
        log_success "Last Updated 존재: $last_updated"

        # 날짜가 2025년인지 확인
        if echo "$last_updated" | grep -q "2025"; then
            log_success "Last Updated 날짜가 최신입니다"
        else
            log_warning "Last Updated 날짜가 오래되었을 수 있습니다"
        fi
    else
        log_warning "Last Updated 날짜가 없습니다"
    fi

    # 코드 블록 확인 (최소 3개의 코드 예제)
    local code_blocks=$(grep -c '```' "$readme" || echo 0)
    if [[ $code_blocks -ge 6 ]]; then  # ``` 가 쌍으로 나오므로 6개 = 3개 코드 블록
        log_success "코드 예제 충분 ($((code_blocks / 2))개)"
    else
        log_warning "코드 예제가 부족합니다 ($((code_blocks / 2))개 < 3개)"
    fi

    # examples 디렉토리 확인
    if [[ -d "$dir/examples" ]]; then
        log_success "examples 디렉토리 존재"

        # examples/basic 디렉토리 확인
        if [[ -d "$dir/examples/basic" ]]; then
            log_success "examples/basic 디렉토리 존재"

            # basic 예제에 README.md 확인
            if [[ -f "$dir/examples/basic/README.md" ]]; then
                log_success "examples/basic/README.md 존재"
            else
                log_warning "examples/basic/README.md 없음"
            fi
        else
            log_warning "examples/basic 디렉토리 없음"
        fi
    else
        log_warning "examples 디렉토리 없음"
    fi

    # variables.tf 파일 확인
    if [[ -f "$dir/variables.tf" ]]; then
        log_success "variables.tf 파일 존재"
    else
        log_warning "variables.tf 파일 없음"
    fi

    # outputs.tf 파일 확인
    if [[ -f "$dir/outputs.tf" ]]; then
        log_success "outputs.tf 파일 존재"
    else
        log_warning "outputs.tf 파일 없음"
    fi
}

# 메인 실행
main() {
    echo ""
    echo "🔍 Terraform Documentation Check"
    echo "=================================="

    # 검증할 디렉토리 결정
    if [[ -n "$1" ]]; then
        # 특정 디렉토리만 검증
        if [[ -d "$1" ]]; then
            check_readme "$1" || true  # Continue even if check fails
        else
            log_error "디렉토리를 찾을 수 없습니다: $1"
            exit 1
        fi
    else
        # terraform 디렉토리 내 모든 패키지 검증
        log_info "terraform/ 디렉토리의 모든 패키지를 검증합니다..."

        # 검증에서 제외할 디렉토리 목록
        EXCLUDED_DIRS=("archived" "modules" "test" "bootstrap")

        # terraform 직하위 디렉토리 검색
        for dir in terraform/*/; do
            # 디렉토리가 실제로 존재하는지 확인
            if [[ -d "$dir" ]]; then
                # .terraform, .git 등 숨김 디렉토리 제외
                dirname=$(basename "$dir")

                # 제외 목록 확인
                skip_dir=false
                for excluded in "${EXCLUDED_DIRS[@]}"; do
                    if [[ "$dirname" == "$excluded" ]]; then
                        skip_dir=true
                        log_info "검증 제외: $dir (특수 디렉토리)"
                        break
                    fi
                done

                if [[ ! "$dirname" =~ ^\. ]] && [[ "$skip_dir" == false ]]; then
                    check_readme "$dir" || true  # Continue even if check fails
                fi
            fi
        done

        # terraform/ecr 하위 서비스 디렉토리도 검증
        if [[ -d "terraform/ecr" ]]; then
            for service_dir in terraform/ecr/*/; do
                if [[ -d "$service_dir" ]]; then
                    dirname=$(basename "$service_dir")
                    if [[ ! "$dirname" =~ ^\. ]] && [[ -f "$service_dir/main.tf" ]]; then
                        check_readme "$service_dir" || true  # Continue even if check fails
                    fi
                fi
            done
        fi
    fi

    # 최종 결과 출력
    echo ""
    echo "=================================================="
    echo "🏁 검증 완료"
    echo "=================================================="
    echo -e "${RED}에러: $TOTAL_ERRORS${NC}"
    echo -e "${YELLOW}경고: $TOTAL_WARNINGS${NC}"

    if [[ $TOTAL_ERRORS -gt 0 ]]; then
        echo -e "${RED}❌ 문서 검증 실패: $TOTAL_ERRORS개의 에러가 있습니다.${NC}"
        exit 1
    elif [[ $TOTAL_WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  문서 검증 통과 (경고 있음): $TOTAL_WARNINGS개의 경고가 있습니다.${NC}"
        exit 0
    else
        echo -e "${GREEN}✅ 문서 검증 성공: 모든 검사를 통과했습니다!${NC}"
        exit 0
    fi
}

# 스크립트 실행
main "$@"
