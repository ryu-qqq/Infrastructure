# Shared RDS (Import용)

현재 운영 중인 RDS `prod-shared-mysql`를 Terraform State로 import하기 위한 설정

## 📋 개요

이 디렉토리는 **기존 RDS를 Terraform으로 관리**하기 위한 것입니다.

- **기존 RDS Import**: `prod-shared-mysql` → Terraform State
- **SSM Parameter 생성**: Cross-stack 참조용 6개 Parameters
- **공유 데이터베이스 관리**: 다른 프로젝트가 참조 가능

## 🚀 빠른 Import

```bash
cd terraform/shared/rds/

# 1. Import 실행
./import.sh

# 2. 변경사항 확인 (SSM Parameters만 생성 예정)
terraform plan

# 3. SSM Parameters 생성
terraform apply
```

## 📊 Import될 리소스

```
✅ aws_db_instance.main              (prod-shared-mysql)
✅ aws_db_subnet_group.main          (prod-shared-mysql-subnet-group)
✅ aws_db_parameter_group.main       (prod-shared-mysql-params)
✅ aws_security_group.main           (sg-0d9b6f65239b16b44)
✅ aws_iam_role.monitoring[0]        (prod-shared-mysql-monitoring-role)
```

## 🔄 다른 프로젝트에서 참조

```hcl
# DB Endpoint 참조
data "aws_ssm_parameter" "db_endpoint" {
  name = "/shared/connectly/database/prod-shared-mysql/endpoint"
}

# DB Secret 참조
data "aws_ssm_parameter" "db_secret_arn" {
  name = "/shared/connectly/database/prod-shared-mysql/secret-arn"
}

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = data.aws_ssm_parameter.db_secret_arn.value
}

# 사용 예제
locals {
  db_host = split(":", data.aws_ssm_parameter.db_endpoint.value)[0]
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)
}
```

## ⚠️ 주의사항

- **lifecycle ignore_changes**: 기존 태그 및 설정 보존
- **변경사항 확인**: import 후 `terraform plan`에서 SSM Parameters만 생성되어야 함
- **Security Group**: 기존 inline 규칙 유지

상세 가이드: [templates/rds/README.md](../../templates/rds/README.md)

---

**유지보수**: Platform Team
**최종 업데이트**: 2025-11-21
