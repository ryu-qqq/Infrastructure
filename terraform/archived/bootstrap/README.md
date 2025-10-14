# Bootstrap Configuration (Archived)

## 상태 (Status)

⚠️ **이 디렉토리는 더 이상 활발히 사용되지 않습니다.**

이 디렉토리는 인프라 초기 설정(bootstrap)을 위한 Terraform 구성을 관리했던 영역입니다. 현재는 Terraform lock 파일만 남아있으며, Terraform 코드 파일들(.tf)과 state 파일은 존재하지 않습니다.

## 목적 (Purpose)

Bootstrap 구성은 일반적으로 다음과 같은 초기 설정을 담당합니다:
- Terraform backend 설정 (S3 bucket, DynamoDB table)
- 기본 네트워크 구성 (VPC, Subnets)
- 공통 IAM 역할 및 정책
- 기본 보안 그룹
- KMS 키 생성

## 현재 상태 (Current State)

디렉토리에는 다음 파일만 존재합니다:
- `.terraform/` - Terraform provider 캐시
- `.terraform.lock.hcl` - Provider 버전 잠금 파일

Terraform state 파일이 없으므로 이 구성으로 관리되던 리소스가:
1. 이미 다른 Terraform 구성으로 이관되었거나
2. 수동으로 생성/관리되고 있거나
3. 더 이상 필요하지 않아 삭제되었을 가능성이 있습니다.

## 권장 조치 (Recommended Actions)

### 옵션 1: 디렉토리 정리
더 이상 사용하지 않는다면:
```bash
# 디렉토리 완전 삭제
rm -rf terraform/bootstrap/
```

### 옵션 2: 아카이브
참고용으로 보관:
```bash
# 아카이브 디렉토리로 이동
mkdir -p ../archived
mv terraform/bootstrap ../archived/
```

### 옵션 3: 재활용
Bootstrap 구성이 필요하다면:
```bash
# 새로운 bootstrap 구성 생성
# terraform/ 디렉토리 구조 참고하여 재작성
```

## Bootstrap 구성 모범 사례 (Best Practices)

만약 새로운 bootstrap 구성을 만든다면:

### 1. Backend 구성
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "your-terraform-state"
    key            = "bootstrap/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

### 2. 필수 리소스
- S3 bucket for Terraform state
- DynamoDB table for state locking
- KMS key for encryption
- IAM roles for Terraform execution

### 3. 거버넌스 태그
```hcl
locals {
  required_tags = {
    Environment = "shared"
    Service     = "terraform-backend"
    Team        = "platform-team"
    Owner       = "platform-team@company.com"
    CostCenter  = "infrastructure"
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }
}
```

## 참고 문서 (References)

- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/configuration)
- [AWS Bootstrap Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/bootstrapping.html)
- [Infrastructure Governance](../../docs/infrastructure_governance.md)

## 문의 (Contact)

- Infrastructure Team
- [Infrastructure Documentation](../../docs/)
