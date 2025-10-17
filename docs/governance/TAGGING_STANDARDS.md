# AWS 리소스 태그 표준

## 개요

AWS 인프라의 효율적인 관리, 비용 추적, 보안 및 거버넌스를 위한 표준 태그 스키마입니다. 모든 AWS 리소스는 아래 정의된 필수 태그를 반드시 포함해야 합니다.

## 필수 태그 (Required Tags)

모든 AWS 리소스에 반드시 포함되어야 하는 태그입니다.

### 1. Environment

**목적**: 리소스가 속한 환경 식별
**형식**: 정해진 값 중 선택
**허용값**: `dev`, `staging`, `prod`

```hcl
Environment = "prod"
```

**사용 예**:
- 환경별 비용 분석
- 환경별 리소스 필터링
- 환경별 액세스 제어

### 2. Service

**목적**: 리소스가 속한 서비스 또는 애플리케이션 식별
**형식**: kebab-case (소문자, 숫자, 하이픈)
**예시**: `api`, `web`, `database`, `network`, `auth-service`

```hcl
Service = "api"
```

**사용 예**:
- 서비스별 리소스 그룹화
- 서비스별 비용 추적
- 마이크로서비스 아키텍처 관리

### 3. Team

**목적**: 리소스를 관리하는 팀 식별
**형식**: kebab-case (소문자, 숫자, 하이픈)
**예시**: `platform-team`, `backend-team`, `frontend-team`, `devops-team`

```hcl
Team = "platform-team"
```

**사용 예**:
- 책임 소재 명확화
- 팀별 리소스 소유권 추적
- 온콜 및 인시던트 대응

### 4. Owner

**목적**: 리소스 소유자 또는 담당자 식별
**형식**: 이메일 주소 또는 kebab-case 식별자
**예시**: `john.doe@company.com`, `platform-team`

```hcl
Owner = "platform-team@company.com"
```

**사용 예**:
- 리소스 변경 시 담당자 연락
- 비용 책임자 식별
- 리소스 수명 주기 관리

### 5. CostCenter

**목적**: 비용 청구 및 예산 추적을 위한 비용 센터
**형식**: kebab-case (소문자, 숫자, 하이픈)
**예시**: `infrastructure`, `product-development`, `research`

```hcl
CostCenter = "infrastructure"
```

**사용 예**:
- 부서별/프로젝트별 비용 배분
- 예산 관리 및 추적
- 재무 보고

### 6. ManagedBy

**목적**: 리소스 관리 방법 식별
**형식**: 정해진 값 중 선택
**허용값**: `terraform`, `manual`, `cloudformation`, `cdk`
**기본값**: `terraform`

```hcl
ManagedBy = "terraform"
```

**사용 예**:
- 자동화 여부 확인
- 리소스 변경 프로세스 결정
- IaC 도구 추적

### 7. Project

**목적**: 리소스가 속한 프로젝트 또는 이니셔티브
**형식**: kebab-case (소문자, 숫자, 하이픈)
**예시**: `infrastructure`, `user-analytics`, `payment-system`
**기본값**: `infrastructure`

```hcl
Project = "infrastructure"
```

**사용 예**:
- 프로젝트별 리소스 그룹화
- 프로젝트 비용 추적
- 프로젝트 수명 주기 관리

## 선택적 태그 (Optional Tags)

특정 리소스 유형이나 용도에 따라 추가할 수 있는 태그입니다.

### DataClass

**목적**: 데이터 민감도 수준 식별 (보안 중요)
**허용값**: `public`, `internal`, `confidential`, `highly-confidential`

```hcl
DataClass = "highly-confidential"
```

**적용 대상**: 데이터를 저장하는 리소스 (RDS, S3, DynamoDB 등)

### Component

**목적**: 서비스 내 세부 컴포넌트 식별
**예시**: `api-server`, `cache`, `queue`, `storage`

```hcl
Component = "api-server"
```

### Lifecycle

**목적**: 리소스의 라이프사이클 단계
**허용값**: `development`, `testing`, `production`, `deprecated`

```hcl
Lifecycle = "production"
```

### BackupPolicy

**목적**: 백업 정책 식별
**예시**: `daily`, `weekly`, `none`

```hcl
BackupPolicy = "daily"
```

### Compliance

**목적**: 규제 준수 요구사항
**예시**: `pci-dss`, `hipaa`, `gdpr`, `sox`

```hcl
Compliance = "gdpr"
```

## Terraform에서 사용

### 공통 태그 모듈 사용

```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "api"
  team        = "platform-team"
  owner       = "platform-team@company.com"
  cost_center = "infrastructure"
  managed_by  = "terraform"
  project     = "infrastructure"

  additional_tags = {
    DataClass = "confidential"
    Component = "backend"
  }
}

resource "aws_instance" "api" {
  # ... other configuration

  tags = module.common_tags.tags
}
```

### 개별 리소스에 직접 적용

```hcl
locals {
  required_tags = {
    Environment = var.environment
    Service     = var.service
    Team        = "platform-team"
    Owner       = "platform-team@company.com"
    CostCenter  = "infrastructure"
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }
}

resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"

  tags = merge(local.required_tags, {
    Name      = "my-data-bucket"
    DataClass = "confidential"
  })
}
```

## 태그 검증

### OPA (Open Policy Agent) 정책

모든 리소스는 배포 전에 OPA 정책을 통해 태그 준수 여부를 자동으로 검증합니다.

```bash
# Terraform plan을 OPA로 검증
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
opa eval --data policies/ --input tfplan.json "data.terraform.deny"
```

### 태그 검증 규칙

1. **필수 태그 존재 여부**: 모든 필수 태그가 포함되어 있는지 확인
2. **태그 값 형식**: 각 태그 값이 정의된 형식을 따르는지 확인
3. **허용값 검증**: 정해진 값 중 하나인지 확인 (Environment, ManagedBy 등)
4. **kebab-case 검증**: kebab-case 형식을 따르는지 확인

## AWS 태그 정책 (Organizations)

AWS Organizations를 사용하는 경우, 태그 정책을 통해 조직 수준에서 강제할 수 있습니다.

```json
{
  "tags": {
    "Environment": {
      "tag_key": {
        "@@assign": "Environment"
      },
      "tag_value": {
        "@@assign": ["dev", "staging", "prod"]
      },
      "enforced_for": {
        "@@assign": ["ec2:instance", "rds:db", "s3:bucket"]
      }
    }
  }
}
```

## 비용 할당 태그

AWS Cost Explorer에서 다음 태그를 활성화하여 비용을 추적합니다:

1. `Environment`
2. `Service`
3. `Team`
4. `CostCenter`
5. `Project`

### 비용 할당 태그 활성화

```bash
aws ce update-cost-allocation-tags-status \
  --cost-allocation-tags-status \
  TagKey=Environment,Status=Active \
  TagKey=Service,Status=Active \
  TagKey=Team,Status=Active \
  TagKey=CostCenter,Status=Active \
  TagKey=Project,Status=Active
```

## 태그 정책 위반 처리

### 자동 거부

- CI/CD 파이프라인에서 OPA 정책 위반 시 자동으로 배포 차단
- Terraform validate 단계에서 태그 검증 실패 시 에러 발생

### 수동 검토

- 기존 리소스에 대한 태그 미준수는 별도 이슈로 추적
- 분기별 태그 준수율 리뷰 및 개선 계획 수립

## 태그 마이그레이션

기존 리소스에 표준 태그를 적용하는 방법:

```bash
# 1. 현재 태그 상태 조사
aws resourcegroupstaggingapi get-resources --query 'ResourceTagMappingList[*].[ResourceARN,Tags]' --output json

# 2. 태그 일괄 업데이트 (예: S3 버킷)
aws s3api put-bucket-tagging --bucket my-bucket --tagging 'TagSet=[{Key=Environment,Value=prod},{Key=Service,Value=api}]'

# 3. Terraform import 및 태그 적용
terraform import aws_s3_bucket.my_bucket my-bucket
```

## 예외 처리

특정 상황에서 태그 정책의 예외가 필요한 경우:

1. **승인 프로세스**: Platform Team에 예외 요청서 제출
2. **임시 예외**: 최대 30일, 자동 만료
3. **영구 예외**: 아키텍처 리뷰 위원회 승인 필요
4. **문서화**: 예외 사유 및 승인 내역을 문서화

## 모범 사례

1. **일관성 유지**: 모든 환경에서 동일한 태그 구조 사용
2. **자동화**: Terraform 모듈을 통해 태그를 자동으로 적용
3. **정기 감사**: 분기별 태그 준수율 검토
4. **교육**: 새 팀원에게 태그 정책 교육 실시
5. **모니터링**: AWS Config 규칙을 통해 태그 준수 모니터링

## 참고 자료

- [AWS Tagging Best Practices](https://aws.amazon.com/answers/account-management/aws-tagging-strategies/)
- [Terraform AWS Provider - Default Tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags)
- [OPA - Open Policy Agent](https://www.openpolicyagent.org/)

## 문의

태그 정책 관련 문의사항은 Platform Team에 연락하세요:
- Email: platform-team@company.com
- Slack: #platform-infrastructure
