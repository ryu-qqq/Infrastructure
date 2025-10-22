#!/bin/bash
# generate-terraform-docs.sh
# Terraform 문서 자동 생성/업데이트 스크립트
#
# 사용법:
#   ./scripts/generate-terraform-docs.sh terraform/rds      # 특정 패키지의 variables.tf, outputs.tf 문서화
#   ./scripts/generate-terraform-docs.sh --all              # 모든 패키지 문서화
#
# 주의: 이 스크립트는 terraform-docs 도구를 사용합니다.
# 설치: brew install terraform-docs (macOS) 또는 https://terraform-docs.io/

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# terraform-docs 설치 확인
check_terraform_docs() {
    if ! command -v terraform-docs &> /dev/null; then
        log_error "terraform-docs가 설치되어 있지 않습니다."
        echo ""
        echo "설치 방법:"
        echo "  macOS: brew install terraform-docs"
        echo "  Linux: https://terraform-docs.io/user-guide/installation/"
        echo ""
        exit 1
    fi

    local version=$(terraform-docs --version | head -1)
    log_success "terraform-docs 설치됨: $version"
}

# Variables 섹션 생성
generate_variables_section() {
    local dir=$1
    local variables_file="$dir/variables.tf"

    if [[ ! -f "$variables_file" ]]; then
        log_warning "variables.tf 파일이 없습니다: $dir"
        return 1
    fi

    echo "## Variables"
    echo ""
    echo "| Name | Description | Type | Default | Required |"
    echo "|------|-------------|------|---------|----------|"

    # terraform-docs를 사용하여 variables 테이블 생성
    terraform-docs markdown table "$dir" 2>/dev/null | \
        grep -A 1000 "## Inputs" | \
        grep -v "## Inputs" | \
        grep -v "^$" | \
        head -n -1 || echo "| - | - | - | - | - |"

    echo ""
}

# Outputs 섹션 생성
generate_outputs_section() {
    local dir=$1
    local outputs_file="$dir/outputs.tf"

    if [[ ! -f "$outputs_file" ]]; then
        log_warning "outputs.tf 파일이 없습니다: $dir"
        return 1
    fi

    echo "## Outputs"
    echo ""
    echo "| Name | Description |"
    echo "|------|-------------|"

    # terraform-docs를 사용하여 outputs 테이블 생성
    terraform-docs markdown table "$dir" 2>/dev/null | \
        grep -A 1000 "## Outputs" | \
        grep -v "## Outputs" | \
        grep -v "^$" || echo "| - | - |"

    echo ""
}

# 전체 문서 생성 (terraform-docs 표준 형식)
generate_full_docs() {
    local dir=$1
    local readme="$dir/README.md"

    log_info "전체 문서 생성: $dir"

    # terraform-docs 설정 파일 생성 (임시)
    cat > "$dir/.terraform-docs.yml" <<EOF
formatter: markdown table

sections:
  show:
    - header
    - requirements
    - providers
    - inputs
    - outputs

content: |-
  # {{ .Header }}

  {{ .Requirements }}

  {{ .Providers }}

  {{ .Inputs }}

  {{ .Outputs }}

output:
  file: README.md
  mode: replace

sort:
  enabled: true
  by: name
EOF

    # terraform-docs 실행
    if terraform-docs markdown table "$dir" > "${readme}.new" 2>/dev/null; then
        mv "${readme}.new" "$readme"
        log_success "문서 생성 완료: $readme"

        # 임시 설정 파일 삭제
        rm -f "$dir/.terraform-docs.yml"
    else
        log_error "문서 생성 실패: $dir"
        rm -f "$dir/.terraform-docs.yml"
        return 1
    fi
}

# README의 특정 섹션만 업데이트
update_readme_section() {
    local dir=$1
    local readme="$dir/README.md"

    if [[ ! -f "$readme" ]]; then
        log_warning "README.md 파일이 없습니다. 전체 문서를 생성합니다."
        generate_full_docs "$dir"
        return
    fi

    log_info "README 업데이트 중: $dir"

    # Variables 섹션 생성
    local vars_content="/tmp/vars_$$. md"
    generate_variables_section "$dir" > "$vars_content"

    # Outputs 섹션 생성
    local outputs_content="/tmp/outputs_$$.md"
    generate_outputs_section "$dir" > "$outputs_content"

    # Python을 사용한 섹션 교체 (더 안정적)
    python3 - "$readme" "$vars_content" "$outputs_content" <<'PYTHON'
import sys
import re

readme_file = sys.argv[1]
vars_file = sys.argv[2]
outputs_file = sys.argv[3]

# README 읽기
with open(readme_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Variables 섹션 읽기
with open(vars_file, 'r', encoding='utf-8') as f:
    vars_content = f.read()

# Outputs 섹션 읽기
with open(outputs_file, 'r', encoding='utf-8') as f:
    outputs_content = f.read()

# Variables 섹션 교체
# ## Variables 부터 다음 ## 까지 또는 파일 끝까지
vars_pattern = r'(## Variables.*?)(?=\n## |\Z)'
if re.search(vars_pattern, content, re.DOTALL):
    content = re.sub(vars_pattern, vars_content.rstrip(), content, flags=re.DOTALL)
else:
    # Variables 섹션이 없으면 추가
    content += '\n\n' + vars_content

# Outputs 섹션 교체
outputs_pattern = r'(## Outputs.*?)(?=\n## |\Z)'
if re.search(outputs_pattern, content, re.DOTALL):
    content = re.sub(outputs_pattern, outputs_content.rstrip(), content, flags=re.DOTALL)
else:
    # Outputs 섹션이 없으면 추가
    content += '\n\n' + outputs_content

# README 업데이트
with open(readme_file, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"✅ README 업데이트 완료: {readme_file}")
PYTHON

    # 임시 파일 삭제
    rm -f "$vars_content" "$outputs_content"

    log_success "README 업데이트 완료: $readme"
}

# 단일 패키지 처리
process_package() {
    local dir=$1

    echo ""
    echo "=================================================="
    log_info "처리 중: $dir"
    echo "=================================================="

    # variables.tf 또는 outputs.tf가 있는지 확인
    if [[ ! -f "$dir/variables.tf" ]] && [[ ! -f "$dir/outputs.tf" ]]; then
        log_warning "Terraform 파일이 없습니다. 건너뜁니다."
        return
    fi

    # README가 있으면 섹션만 업데이트, 없으면 전체 생성
    if [[ -f "$dir/README.md" ]]; then
        update_readme_section "$dir"
    else
        generate_full_docs "$dir"
    fi
}

# 메인 실행
main() {
    echo ""
    echo "📝 Terraform Documentation Generator"
    echo "====================================="

    # terraform-docs 설치 확인
    check_terraform_docs

    # 처리할 디렉토리 결정
    if [[ "$1" == "--all" ]]; then
        log_info "모든 Terraform 패키지를 처리합니다..."

        # terraform 직하위 디렉토리 처리
        for dir in terraform/*/; do
            if [[ -d "$dir" ]]; then
                dirname=$(basename "$dir")
                if [[ ! "$dirname" =~ ^\. ]]; then
                    process_package "$dir"
                fi
            fi
        done

        # terraform/ecr 하위 서비스 디렉토리도 처리
        if [[ -d "terraform/ecr" ]]; then
            for service_dir in terraform/ecr/*/; do
                if [[ -d "$service_dir" ]]; then
                    dirname=$(basename "$service_dir")
                    if [[ ! "$dirname" =~ ^\. ]] && [[ -f "$service_dir/main.tf" ]]; then
                        process_package "$service_dir"
                    fi
                fi
            done
        fi

    elif [[ -n "$1" ]]; then
        # 특정 디렉토리만 처리
        if [[ -d "$1" ]]; then
            process_package "$1"
        else
            log_error "디렉토리를 찾을 수 없습니다: $1"
            exit 1
        fi
    else
        echo "사용법:"
        echo "  $0 terraform/rds        # 특정 패키지만 처리"
        echo "  $0 --all                # 모든 패키지 처리"
        exit 1
    fi

    # 최종 결과
    echo ""
    echo "=================================================="
    log_success "문서 생성 완료!"
    echo "=================================================="
}

# 스크립트 실행
main "$@"
