# Secrets Stack Refactoring Summary

## 개요
terraform/environments/prod/secrets 스택을 modules v1.0.0 패턴으로 리팩토링했습니다.

## 변경사항

### 1. 모듈 통합

#### Lambda Function (rotation.tf)
**이전:**
- Raw `aws_lambda_function` 리소스
- Raw `aws_iam_role` 및 inline policies
- Raw `aws_cloudwatch_log_group`

**이후:**
```hcl
module "rotation_lambda_role" {
  source = "../../../modules/iam-role-policy"

  # Secrets Manager policy 활성화
  enable_secrets_manager_policy = true
  secrets_manager_allow_update  = true

  # CloudWatch Logs policy 활성화
  enable_cloudwatch_logs_policy = true

  # Custom inline policies (RDS, GetRandomPassword)
  custom_inline_policies = { ... }
}

module "rotation_lambda" {
  source = "../../../modules/lambda"

  # 외부 IAM role 사용
  create_role     = false
  lambda_role_arn = module.rotation_lambda_role.role_arn

  # CloudWatch Logs 자동 생성
  create_log_group   = true
  log_kms_key_id     = local.cloudwatch_logs_kms_key_arn
}
```

**장점:**
- IAM policy 관리 일관성 확보 (iam-role-policy 모듈의 정책 패턴 활용)
- CloudWatch Logs 자동 생성 및 KMS 암호화 적용
- VPC configuration 동적 처리
- 모듈 재사용성 향상

### 2. locals.tf 개선

**추가된 항목:**
```hcl
data "aws_region" "current" {}

locals {
  # Region 자동 감지
  region = data.aws_region.current.name

  # KMS key ARN 추가
  cloudwatch_logs_kms_key_arn = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn

  # Lambda 설정 중앙화
  lambda_function_name = "secrets-manager-rotation"
  lambda_log_group     = "/aws/lambda/${local.lambda_function_name}"

  # Lifecycle 태그 추가
  required_tags = {
    ...
    Lifecycle = "permanent"
  }
}
```

**개선점:**
- Region을 하드코딩 대신 data source로 자동 감지
- CloudWatch Logs KMS key 참조 추가
- Lambda 관련 설정 중앙 관리

### 3. variables.tf 강화

**추가된 validation:**
```hcl
variable "team" {
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.team))
    error_message = "Team must use kebab-case"
  }
}

variable "data_class" {
  default = "highly-confidential"
  validation {
    condition     = contains(["highly-confidential", "confidential", "internal", "public"], var.data_class)
    error_message = "Data class must be one of: highly-confidential, confidential, internal, public."
  }
}
```

**개선점:**
- 모든 필수 태그 변수에 kebab-case validation 추가
- data_class에 "highly-confidential" 옵션 추가
- 변수 설명 명확화

### 4. main.tf 단순화

**변경사항:**
- Secrets Manager 리소스는 raw 리소스로 유지 (모듈화 불필요)
- 태그에 `Component = "secret"` 추가
- Lambda ARN 참조를 모듈 output으로 변경: `module.rotation_lambda.function_arn`

### 5. outputs.tf 업데이트

**추가된 outputs:**
```hcl
output "rotation_lambda_name" {
  description = "Name of the rotation Lambda function"
  value       = module.rotation_lambda.function_name
}

output "rotation_lambda_role_name" {
  description = "Name of the rotation Lambda execution role"
  value       = module.rotation_lambda_role.role_name
}
```

## 유지된 리소스

다음 리소스들은 raw 리소스로 유지:

1. **Secrets Manager Secrets** (`main.tf`)
   - 서비스별로 고유한 구조를 가지므로 모듈화 불필요
   - 태그만 표준화

2. **Security Group** (`rotation.tf`)
   - Lambda 전용 보안 그룹으로 재사용성 낮음
   - VPC 조건부 생성 로직 유지

3. **Lambda Permission** (`rotation.tf`)
   - Secrets Manager 특화 권한
   - 단순한 리소스로 모듈화 불필요

4. **CloudWatch Alarms** (`rotation.tf`)
   - Lambda 모니터링 전용
   - 메트릭과 임계값이 Lambda 특화

5. **IAM Policies** (`policies.tf`)
   - 서비스별 세밀한 권한 정의 필요
   - 표준 모듈로 처리 불가능한 비즈니스 로직 포함

## 파일 구조

```
terraform/environments/prod/secrets/
├── provider.tf              # 백엔드 및 provider 설정
├── locals.tf                # ✅ 개선: region, KMS key ARN 추가
├── variables.tf             # ✅ 개선: validation 강화
├── main.tf                  # ✅ 수정: 모듈 output 참조
├── rotation.tf              # ✅ 리팩토링: 모듈 사용
├── policies.tf              # ⚪ 유지: 서비스별 정책
├── outputs.tf               # ✅ 수정: 모듈 output 추가
├── lambda/                  # ⚪ 유지: Python 코드
│   ├── rotation.zip
│   ├── index.py
│   └── ...
└── REFACTORING_SUMMARY.md   # 이 문서
```

## 검증

### Terraform Formatting
```bash
cd terraform/environments/prod/secrets
terraform fmt -check -recursive
# ✅ 모든 파일 포맷팅 통과
```

### 주요 변경점 검증
- ✅ Lambda 모듈 통합 (iam-role-policy + lambda)
- ✅ Required tags 모든 리소스 적용
- ✅ KMS 암호화 적용 (Secrets Manager, CloudWatch Logs)
- ✅ Naming convention 준수 (kebab-case)
- ✅ Lambda Python 코드 유지 (`lambda/` 디렉터리)

## 마이그레이션 노트

### Backend 설정 변경
`provider.tf`에서 S3 backend region을 `us-east-1`로 수정했습니다:
```hcl
backend "s3" {
  bucket = "prod-tfstate"
  key    = "environments/prod/secrets/terraform.tfstate"
  region = "us-east-1"  # 이전: ap-northeast-2
}
```

**이유:** 실제 S3 버킷이 `us-east-1`에 위치함

### 모듈 경로
```hcl
source = "../../../modules/iam-role-policy"  # terraform/modules/iam-role-policy
source = "../../../modules/lambda"           # terraform/modules/lambda
```

## 다음 단계

1. **Terraform init 및 plan 실행**
   ```bash
   cd terraform/environments/prod/secrets
   terraform init -reconfigure
   terraform plan
   ```

2. **State migration 확인**
   - Lambda function: `aws_lambda_function.rotation` → `module.rotation_lambda.aws_lambda_function.this`
   - IAM role: `aws_iam_role.rotation-lambda` → `module.rotation_lambda_role.aws_iam_role.this`
   - CloudWatch Logs: `aws_cloudwatch_log_group.rotation-lambda` → `module.rotation_lambda.aws_cloudwatch_log_group.lambda[0]`

3. **Apply 실행**
   ```bash
   terraform apply
   ```

## 참고

- [Module Development Standards](../../../modules/README.md)
- [Tagging Strategy](../../../../docs/governance/TAGGING_STRATEGY.md)
- [IAM Role Policy Module](../../../modules/iam-role-policy/README.md)
- [Lambda Module](../../../modules/lambda/README.md)
