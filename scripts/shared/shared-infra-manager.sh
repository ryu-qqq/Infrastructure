#!/usr/bin/env bash

# Shared Infrastructure Reference Manager
# Helps other projects reference existing shared infrastructure resources
# Compatible with Bash 3.2+ (macOS default)

set -e

# Configuration
INFRASTRUCTURE_PATH="/Users/sangwon-ryu/infrastructure"
AWS_REGION="ap-northeast-2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_header() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Get resource metadata
get_resource_metadata() {
    local resource=$1

    case $resource in
        tfstate)
            echo "Terraform State Storage|S3 bucket for Terraform remote state|terraform/bootstrap"
            ;;
        tflock)
            echo "Terraform State Lock|DynamoDB table for state locking|terraform/bootstrap"
            ;;
        vpc)
            echo "VPC Network|Shared VPC for all services|terraform/network"
            ;;
        subnets)
            echo "Network Subnets|Public, Private, Data subnets|terraform/network"
            ;;
        rds)
            echo "RDS MySQL Database|Shared MySQL database|terraform/rds"
            ;;
        kms)
            echo "KMS Encryption Keys|Customer-managed encryption keys|terraform/kms"
            ;;
        amp)
            echo "Amazon Managed Prometheus|Prometheus for metrics|terraform/monitoring"
            ;;
        amg)
            echo "Amazon Managed Grafana|Grafana for dashboards|terraform/monitoring"
            ;;
        route53)
            echo "Route53 Hosted Zone|DNS management|terraform/route53"
            ;;
        acm)
            echo "ACM Certificates|SSL/TLS certificates|terraform/acm"
            ;;
        secrets)
            echo "Secrets Manager|Centralized secrets storage|terraform/secrets"
            ;;
        cloudtrail)
            echo "CloudTrail Audit|API audit logging|terraform/cloudtrail"
            ;;
        logging)
            echo "CloudWatch Logs|Centralized logging infrastructure|terraform/logging"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Get SSM parameter path
get_ssm_path() {
    local resource=$1
    local param=$2

    case "${resource}.${param}" in
        tfstate.bucket) echo "/infrastructure/bootstrap/tfstate-bucket" ;;
        tfstate.kms_key) echo "/infrastructure/bootstrap/tfstate-kms-key-arn" ;;
        tflock.table) echo "/infrastructure/bootstrap/tflock-table" ;;
        vpc.id) echo "/shared/network/vpc-id" ;;
        subnets.public) echo "/shared/network/public-subnet-ids" ;;
        subnets.private) echo "/shared/network/private-subnet-ids" ;;
        rds.id) echo "/shared/rds/db-instance-id" ;;
        rds.address) echo "/shared/rds/db-instance-address" ;;
        rds.port) echo "/shared/rds/db-instance-port" ;;
        rds.secret) echo "/shared/rds/master-password-secret-name" ;;
        rds.security_group) echo "/shared/rds/db-security-group-id" ;;
        kms.logs) echo "/shared/kms/cloudwatch-logs-key-arn" ;;
        kms.secrets) echo "/shared/kms/secrets-manager-key-arn" ;;
        kms.rds) echo "/shared/kms/rds-key-arn" ;;
        kms.s3) echo "/shared/kms/s3-key-arn" ;;
        kms.sqs) echo "/shared/kms/sqs-key-arn" ;;
        kms.ssm) echo "/shared/kms/ssm-key-arn" ;;
        kms.elasticache) echo "/shared/kms/elasticache-key-arn" ;;
        kms.ecs) echo "/shared/kms/ecs-secrets-key-arn" ;;
        *) echo "" ;;
    esac
}

# Get list of SSM parameters for a resource
get_resource_params() {
    local resource=$1

    case $resource in
        tfstate)
            echo "bucket kms_key"
            ;;
        tflock)
            echo "table"
            ;;
        vpc)
            echo "id"
            ;;
        subnets)
            echo "public private"
            ;;
        rds)
            echo "id address port secret security_group"
            ;;
        kms)
            echo "logs secrets rds s3 sqs ssm elasticache ecs"
            ;;
        *)
            echo ""
            ;;
    esac
}

# List all available shared resources
list_resources() {
    print_header "🏢 공유 인프라 리소스 목록"
    echo ""

    local resources="tfstate tflock vpc subnets rds kms amp amg route53 acm secrets cloudtrail logging"

    for resource in $resources; do
        local metadata=$(get_resource_metadata "$resource")
        if [ -n "$metadata" ]; then
            IFS='|' read -r name description path <<< "$metadata"

            echo -e "${GREEN}📦 ${resource}${NC}"
            echo -e "   Name: ${name}"
            echo -e "   Description: ${description}"
            echo -e "   Managed in: ${path}"
            echo ""
        fi
    done

    print_info "사용법: /if/shared info <resource> 로 상세 정보 확인"
    print_info "예시: /if/shared info rds"
}

# Get detailed information about a resource
resource_info() {
    local resource=$1

    if [ -z "$resource" ]; then
        print_error "리소스 이름을 지정하세요: /if/shared info <resource>"
        exit 1
    fi

    local metadata=$(get_resource_metadata "$resource")
    if [ -z "$metadata" ]; then
        print_error "알 수 없는 리소스: $resource"
        echo ""
        print_info "사용 가능한 리소스 목록: /if/shared list"
        exit 1
    fi

    IFS='|' read -r name description path <<< "$metadata"

    print_header "📦 ${name}"
    echo ""
    echo -e "${BLUE}Description:${NC} ${description}"
    echo -e "${BLUE}Managed in:${NC} ${path}"
    echo ""

    # Find related SSM parameters
    local params=$(get_resource_params "$resource")
    if [ -n "$params" ]; then
        print_header "🔑 SSM Parameter Store References"
        echo ""

        for param in $params; do
            local ssm_path=$(get_ssm_path "$resource" "$param")
            if [ -n "$ssm_path" ]; then
                echo -e "${CYAN}${param}:${NC}"
                echo -e "  SSM Path: ${ssm_path}"

                # Try to fetch actual value if AWS CLI available
                if command -v aws &> /dev/null; then
                    local value=$(aws ssm get-parameter --name "$ssm_path" --region "$AWS_REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "N/A")
                    if [ "$value" != "N/A" ]; then
                        echo -e "  Current Value: ${GREEN}${value}${NC}"
                    fi
                fi
                echo ""
            fi
        done
    else
        print_warning "이 리소스에 대한 SSM parameter가 설정되지 않았습니다"
        echo ""
    fi

    # Show Terraform data source example
    print_header "💻 Terraform에서 사용하는 방법"
    echo ""

    show_terraform_example "$resource"

    echo ""
    print_info "Tip: /if/shared get ${resource} 를 실행하면 Terraform 코드가 자동 생성됩니다"
}

# Show Terraform usage example
show_terraform_example() {
    local resource=$1

    case $resource in
        rds)
            cat << 'EOF'
# data.tf
data "aws_ssm_parameter" "rds_address" {
  name = "/shared/rds/db-instance-address"
}

data "aws_ssm_parameter" "rds_port" {
  name = "/shared/rds/db-instance-port"
}

data "aws_ssm_parameter" "rds_secret_name" {
  name = "/shared/rds/master-password-secret-name"
}

data "aws_secretsmanager_secret" "rds" {
  name = data.aws_ssm_parameter.rds_secret_name.value
}

data "aws_secretsmanager_secret_version" "rds" {
  secret_id = data.aws_secretsmanager_secret.rds.id
}

# main.tf - ECS Task Definition에서 사용
resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([{
    name = "app"
    environment = [
      {
        name  = "DB_HOST"
        value = data.aws_ssm_parameter.rds_address.value
      },
      {
        name  = "DB_PORT"
        value = data.aws_ssm_parameter.rds_port.value
      }
    ]
    secrets = [
      {
        name      = "DB_PASSWORD"
        valueFrom = "${data.aws_secretsmanager_secret.rds.arn}:password::"
      },
      {
        name      = "DB_USERNAME"
        valueFrom = "${data.aws_secretsmanager_secret.rds.arn}:username::"
      },
      {
        name      = "DB_NAME"
        valueFrom = "${data.aws_secretsmanager_secret.rds.arn}:dbname::"
      }
    ]
  }])
}
EOF
            ;;

        vpc|subnets)
            cat << 'EOF'
# data.tf
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "/shared/network/public-subnet-ids"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/shared/network/private-subnet-ids"
}

# main.tf - ALB에서 사용
resource "aws_lb" "main" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = split(",", data.aws_ssm_parameter.public_subnet_ids.value)
}

# main.tf - ECS Service에서 사용
resource "aws_ecs_service" "app" {
  network_configuration {
    subnets = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  }
}
EOF
            ;;

        kms)
            cat << 'EOF'
# data.tf
data "aws_ssm_parameter" "kms_rds_key" {
  name = "/shared/kms/rds-key-arn"
}

data "aws_ssm_parameter" "kms_s3_key" {
  name = "/shared/kms/s3-key-arn"
}

# main.tf - S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = data.aws_ssm_parameter.kms_s3_key.value
      sse_algorithm     = "aws:kms"
    }
  }
}
EOF
            ;;

        tfstate|tflock)
            cat << 'EOF'
# provider.tf - Backend 설정
terraform {
  backend "s3" {
    bucket         = "ryuqqq-prod-tfstate"  # From SSM: /infrastructure/bootstrap/tfstate-bucket
    key            = "myapp/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"       # From SSM: /infrastructure/bootstrap/tflock-table
    kms_key_id     = "alias/terraform-state" # From SSM: /infrastructure/bootstrap/tfstate-kms-key-arn"
  }
}
EOF
            ;;

        *)
            cat << 'EOF'
# data.tf - Generic SSM parameter 조회
data "aws_ssm_parameter" "example" {
  name = "/shared/resource/parameter-name"
}

# main.tf - 사용 예시
resource "aws_example" "main" {
  parameter_value = data.aws_ssm_parameter.example.value
}
EOF
            ;;
    esac
}

# Generate Terraform data source code
get_resource_code() {
    local resource=$1

    if [ -z "$resource" ]; then
        print_error "리소스 이름을 지정하세요: /if/shared get <resource>"
        exit 1
    fi

    local metadata=$(get_resource_metadata "$resource")
    if [ -z "$metadata" ]; then
        print_error "알 수 없는 리소스: $resource"
        exit 1
    fi

    IFS='|' read -r name description path <<< "$metadata"

    print_success "Generating Terraform code for: ${name}"
    echo ""

    local output_file="shared-${resource}.tf"

    # Create data.tf content
    cat > "/tmp/${output_file}" << EOF
# Shared Infrastructure Reference: ${name}
# Auto-generated by /if/shared get ${resource}
# Description: ${description}

EOF

    # Add data sources based on resource type
    case $resource in
        rds)
            cat >> "/tmp/${output_file}" << 'EOF'
# RDS Connection Information
data "aws_ssm_parameter" "rds_address" {
  name = "/shared/rds/db-instance-address"
}

data "aws_ssm_parameter" "rds_port" {
  name = "/shared/rds/db-instance-port"
}

data "aws_ssm_parameter" "rds_security_group" {
  name = "/shared/rds/db-security-group-id"
}

# RDS Credentials (from Secrets Manager)
data "aws_ssm_parameter" "rds_secret_name" {
  name = "/shared/rds/master-password-secret-name"
}

data "aws_secretsmanager_secret" "rds" {
  name = data.aws_ssm_parameter.rds_secret_name.value
}

data "aws_secretsmanager_secret_version" "rds" {
  secret_id = data.aws_secretsmanager_secret.rds.id
}

# Decoded credentials
locals {
  rds_credentials = jsondecode(data.aws_secretsmanager_secret_version.rds.secret_string)
  rds_username    = local.rds_credentials.username
  rds_password    = local.rds_credentials.password
  rds_dbname      = local.rds_credentials.dbname
  rds_endpoint    = "${data.aws_ssm_parameter.rds_address.value}:${data.aws_ssm_parameter.rds_port.value}"
}
EOF
            ;;

        vpc|subnets)
            cat >> "/tmp/${output_file}" << 'EOF'
# VPC and Subnet Information
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "/shared/network/public-subnet-ids"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/shared/network/private-subnet-ids"
}

# Parsed subnet lists
locals {
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  public_subnet_ids  = split(",", data.aws_ssm_parameter.public_subnet_ids.value)
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
}
EOF
            ;;

        kms)
            cat >> "/tmp/${output_file}" << 'EOF'
# KMS Encryption Keys
data "aws_ssm_parameter" "kms_logs_key" {
  name = "/shared/kms/cloudwatch-logs-key-arn"
}

data "aws_ssm_parameter" "kms_secrets_key" {
  name = "/shared/kms/secrets-manager-key-arn"
}

data "aws_ssm_parameter" "kms_rds_key" {
  name = "/shared/kms/rds-key-arn"
}

data "aws_ssm_parameter" "kms_s3_key" {
  name = "/shared/kms/s3-key-arn"
}

data "aws_ssm_parameter" "kms_sqs_key" {
  name = "/shared/kms/sqs-key-arn"
}

data "aws_ssm_parameter" "kms_elasticache_key" {
  name = "/shared/kms/elasticache-key-arn"
}

data "aws_ssm_parameter" "kms_ecs_key" {
  name = "/shared/kms/ecs-secrets-key-arn"
}

# KMS Key ARNs
locals {
  kms_logs_key_arn        = data.aws_ssm_parameter.kms_logs_key.value
  kms_secrets_key_arn     = data.aws_ssm_parameter.kms_secrets_key.value
  kms_rds_key_arn         = data.aws_ssm_parameter.kms_rds_key.value
  kms_s3_key_arn          = data.aws_ssm_parameter.kms_s3_key.value
  kms_sqs_key_arn         = data.aws_ssm_parameter.kms_sqs_key.value
  kms_elasticache_key_arn = data.aws_ssm_parameter.kms_elasticache_key.value
  kms_ecs_key_arn         = data.aws_ssm_parameter.kms_ecs_key.value
}
EOF
            ;;
    esac

    print_success "Generated: /tmp/${output_file}"
    echo ""
    echo -e "${BLUE}파일 내용:${NC}"
    cat "/tmp/${output_file}"
    echo ""
    print_info "파일을 프로젝트의 terraform/ 디렉토리로 복사하세요:"
    echo "  cp /tmp/${output_file} terraform/shared-${resource}.tf"
}

# Main command dispatcher
main() {
    local command=$1
    shift

    case $command in
        list)
            list_resources
            ;;
        info)
            resource_info "$@"
            ;;
        get)
            get_resource_code "$@"
            ;;
        *)
            echo "Shared Infrastructure Reference Manager"
            echo ""
            echo "Usage:"
            echo "  $0 list                 - 사용 가능한 공유 인프라 목록"
            echo "  $0 info <resource>      - 공유 인프라 상세 정보 및 SSM parameter"
            echo "  $0 get <resource>       - Terraform data source 코드 생성"
            echo ""
            echo "Available Resources:"
            echo "  rds, vpc, subnets, kms, tfstate, tflock"
            echo "  amp, amg, route53, acm, secrets, cloudtrail, logging"
            echo ""
            echo "Examples:"
            echo "  $0 list"
            echo "  $0 info rds"
            echo "  $0 get rds"
            echo "  $0 get vpc"
            exit 1
            ;;
    esac
}

main "$@"
