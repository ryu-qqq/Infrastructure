#!/bin/bash

# Module Manager for Infrastructure Repository
# Helps other projects consume Terraform modules from this repository

set -e

# Configuration
INFRASTRUCTURE_REPO="https://github.com/ryuqqq/infrastructure.git"
INFRASTRUCTURE_PATH="/Users/sangwon-ryu/infrastructure"
MODULES_PATH="terraform/modules"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Get all available modules with versions
list_modules() {
    print_info "사용 가능한 Infrastructure 모듈 목록:\n"

    cd "$INFRASTRUCTURE_PATH" || exit 1

    # Get all modules
    for module_dir in terraform/modules/*/; do
        if [ -d "$module_dir" ]; then
            module_name=$(basename "$module_dir")

            # Get versions from git tags
            versions=$(git tag -l "modules/${module_name}/v*" 2>/dev/null | sed "s|modules/${module_name}/||" | sort -V)

            # Get latest version from CHANGELOG if no tags
            if [ -z "$versions" ] && [ -f "${module_dir}CHANGELOG.md" ]; then
                latest=$(grep -E "^## \[([0-9]+\.[0-9]+\.[0-9]+)\]" "${module_dir}CHANGELOG.md" | head -1 | sed -E 's/.*\[([0-9]+\.[0-9]+\.[0-9]+)\].*/v\1/')
                if [ -n "$latest" ]; then
                    versions="$latest (CHANGELOG only)"
                fi
            fi

            if [ -n "$versions" ]; then
                latest_version=$(echo "$versions" | tail -1)
                version_count=$(echo "$versions" | wc -l | tr -d ' ')

                echo -e "${GREEN}📦 ${module_name}${NC}"
                echo -e "   Latest: ${BLUE}${latest_version}${NC}"

                if [ "$version_count" -gt 1 ]; then
                    echo -e "   All versions: ${versions}" | tr '\n' ' '
                    echo ""
                fi

                # Show description from README if exists
                if [ -f "${module_dir}README.md" ]; then
                    description=$(grep -E "^#+ " "${module_dir}README.md" | head -2 | tail -1 | sed 's/^#* //')
                    if [ -n "$description" ]; then
                        echo -e "   📝 ${description}"
                    fi
                fi
                echo ""
            else
                echo -e "${YELLOW}📦 ${module_name}${NC} (no versions)"
            fi
        fi
    done
}

# Get detailed info about a specific module
module_info() {
    local module_name=$1

    if [ -z "$module_name" ]; then
        print_error "모듈 이름을 지정하세요: /if/module info <module-name>"
        exit 1
    fi

    local module_path="$INFRASTRUCTURE_PATH/$MODULES_PATH/$module_name"

    if [ ! -d "$module_path" ]; then
        print_error "모듈을 찾을 수 없습니다: $module_name"
        exit 1
    fi

    cd "$INFRASTRUCTURE_PATH" || exit 1

    echo -e "\n${GREEN}📦 Module: ${module_name}${NC}\n"

    # Get versions
    versions=$(git tag -l "modules/${module_name}/v*" 2>/dev/null | sed "s|modules/${module_name}/||" | sort -V)

    if [ -z "$versions" ] && [ -f "${module_path}/CHANGELOG.md" ]; then
        versions=$(grep -E "^## \[([0-9]+\.[0-9]+\.[0-9]+)\]" "${module_path}/CHANGELOG.md" | sed -E 's/.*\[([0-9]+\.[0-9]+\.[0-9]+)\].*/v\1/')
    fi

    if [ -n "$versions" ]; then
        latest_version=$(echo "$versions" | tail -1)
        echo -e "${BLUE}Latest Version:${NC} ${latest_version}"
        echo -e "${BLUE}All Versions:${NC}"
        echo "$versions" | while read -r ver; do
            echo "  - $ver"
        done
        echo ""
    else
        print_warning "버전 정보가 없습니다"
        echo ""
    fi

    # Show README
    if [ -f "${module_path}/README.md" ]; then
        echo -e "${BLUE}Description:${NC}"
        head -20 "${module_path}/README.md"
        echo ""
    fi

    # Show structure
    echo -e "${BLUE}Module Structure:${NC}"
    tree -L 2 "$module_path" 2>/dev/null || ls -la "$module_path"
    echo ""

    # Show usage example
    if [ -f "${module_path}/examples/basic/main.tf" ]; then
        echo -e "${BLUE}Basic Usage Example:${NC}"
        cat "${module_path}/examples/basic/main.tf"
    fi
}

# Get module source reference for use in Terraform
get_module_source() {
    local module_spec=$1
    local module_name=${module_spec%@*}
    local version=${module_spec#*@}

    if [ "$version" = "$module_spec" ]; then
        # No version specified, get latest
        cd "$INFRASTRUCTURE_PATH" || exit 1
        version=$(git tag -l "modules/${module_name}/v*" 2>/dev/null | sed "s|modules/${module_name}/||" | sort -V | tail -1)

        if [ -z "$version" ]; then
            print_warning "No Git tags found for $module_name, using main branch"
            version="main"
        fi
    fi

    local module_path="$INFRASTRUCTURE_PATH/$MODULES_PATH/$module_name"

    if [ ! -d "$module_path" ]; then
        print_error "모듈을 찾을 수 없습니다: $module_name"
        exit 1
    fi

    # Generate Terraform module source
    local git_ref=""
    if [ "$version" != "main" ]; then
        git_ref="modules/${module_name}/${version}"
    else
        git_ref="main"
    fi

    echo ""
    print_success "Module: ${module_name} (${version})"
    echo ""
    echo -e "${BLUE}Terraform에서 사용하는 방법:${NC}"
    echo ""
    echo "module \"${module_name//-/_}\" {"
    echo "  source = \"git::${INFRASTRUCTURE_REPO}//terraform/modules/${module_name}?ref=${git_ref}\""
    echo ""
    echo "  # 여기에 모듈 변수를 추가하세요"
    echo "}"
    echo ""

    # Show available variables
    if [ -f "${module_path}/variables.tf" ]; then
        echo -e "${BLUE}사용 가능한 변수:${NC}"
        grep -E "^variable \"" "${module_path}/variables.tf" | sed 's/variable "/  - /' | sed 's/" {//'
        echo ""
    fi

    print_info "Tip: /if/module init ${module_name} 를 실행하면 자동으로 설정 파일이 생성됩니다"
}

# Initialize module usage in current project
init_module() {
    local module_spec=$1
    local module_name=${module_spec%@*}
    local version=${module_spec#*@}

    if [ -z "$module_name" ]; then
        print_error "모듈 이름을 지정하세요: /if/module init <module-name>[@version]"
        exit 1
    fi

    if [ "$version" = "$module_spec" ]; then
        # No version specified, get latest
        cd "$INFRASTRUCTURE_PATH" || exit 1
        version=$(git tag -l "modules/${module_name}/v*" 2>/dev/null | sed "s|modules/${module_name}/||" | sort -V | tail -1)

        if [ -z "$version" ]; then
            version="main"
        fi
    fi

    local module_path="$INFRASTRUCTURE_PATH/$MODULES_PATH/$module_name"

    if [ ! -d "$module_path" ]; then
        print_error "모듈을 찾을 수 없습니다: $module_name"
        exit 1
    fi

    # Create terraform directory structure if needed
    if [ ! -d "terraform" ]; then
        mkdir -p terraform
        print_success "Created terraform/ directory"
    fi

    # Create module directory
    local target_dir="terraform/${module_name}"
    if [ -d "$target_dir" ]; then
        print_warning "Directory already exists: $target_dir"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            exit 0
        fi
    fi

    mkdir -p "$target_dir"

    # Generate Git ref
    local git_ref=""
    if [ "$version" != "main" ]; then
        git_ref="modules/${module_name}/${version}"
    else
        git_ref="main"
    fi

    # Create main.tf with module reference
    cat > "${target_dir}/main.tf" <<EOF
# ${module_name} Module Configuration
# Version: ${version}
# Auto-generated by /if/module init

module "${module_name//-/_}" {
  source = "git::${INFRASTRUCTURE_REPO}//terraform/modules/${module_name}?ref=${git_ref}"

  # TODO: Configure module variables
  # See variables.tf for available options
}
EOF

    print_success "Created ${target_dir}/main.tf"

    # Copy example if available
    if [ -f "${module_path}/examples/basic/main.tf" ]; then
        cat > "${target_dir}/example.tf.template" <<EOF
# Example configuration from infrastructure repo
# Rename to main.tf or copy contents as needed

EOF
        cat "${module_path}/examples/basic/main.tf" >> "${target_dir}/example.tf.template"
        print_success "Created ${target_dir}/example.tf.template (example configuration)"
    fi

    # Copy variables reference
    if [ -f "${module_path}/variables.tf" ]; then
        cp "${module_path}/variables.tf" "${target_dir}/variables-reference.tf.md"
        print_success "Created ${target_dir}/variables-reference.tf.md (variable documentation)"
    fi

    # Create outputs.tf
    cat > "${target_dir}/outputs.tf" <<EOF
# Outputs from ${module_name} module

output "${module_name//-/_}_outputs" {
  description = "All outputs from ${module_name} module"
  value       = module.${module_name//-/_}
  sensitive   = true
}
EOF

    print_success "Created ${target_dir}/outputs.tf"

    # Create provider.tf if not exists
    if [ ! -f "terraform/provider.tf" ]; then
        cat > "terraform/provider.tf" <<EOF
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # TODO: Configure backend for state management
  # backend "s3" {
  #   bucket = "your-tfstate-bucket"
  #   key    = "${module_name}/terraform.tfstate"
  #   region = "ap-northeast-2"
  # }
}

provider "aws" {
  region = var.aws_region
}
EOF
        print_success "Created terraform/provider.tf"
    fi

    # Create variables.tf if not exists
    if [ ! -f "terraform/variables.tf" ]; then
        cat > "terraform/variables.tf" <<EOF
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}
EOF
        print_success "Created terraform/variables.tf"
    fi

    echo ""
    print_success "Module ${module_name} initialized successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Edit ${target_dir}/main.tf and configure variables"
    echo "  2. Review ${target_dir}/example.tf.template for usage examples"
    echo "  3. Run: cd terraform/${module_name} && terraform init"
    echo "  4. Run: terraform plan"
}

# Main command dispatcher
main() {
    local command=$1
    shift

    case $command in
        list)
            list_modules
            ;;
        info)
            module_info "$@"
            ;;
        get)
            get_module_source "$@"
            ;;
        init)
            init_module "$@"
            ;;
        *)
            echo "Infrastructure Module Manager"
            echo ""
            echo "Usage:"
            echo "  $0 list                      - 사용 가능한 모듈 목록 조회"
            echo "  $0 info <module>             - 모듈 상세 정보 조회"
            echo "  $0 get <module>[@version]    - 모듈 사용법 및 Terraform source 생성"
            echo "  $0 init <module>[@version]   - 현재 프로젝트에 모듈 설정 파일 생성"
            echo ""
            echo "Examples:"
            echo "  $0 list"
            echo "  $0 info ecr"
            echo "  $0 get ecr"
            echo "  $0 get ecr@v1.0.0"
            echo "  $0 init ecr"
            echo "  $0 init alb@v1.0.0"
            exit 1
            ;;
    esac
}

main "$@"
