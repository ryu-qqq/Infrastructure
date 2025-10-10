# Infrastructure Project Rules for Claude Sessions

이 프로젝트에서 Terraform 인프라 코드 작성 시 **반드시** 준수해야 하는 규칙들입니다.
Git 훅은 마지막 방어선이며, 클로드는 코드 생성 시점부터 이 규칙들을 자동으로 적용해야 합니다.

## 🔴 CRITICAL: 필수 준수 사항

### 1. Required Tags (필수 태그)

**모든 AWS 리소스는 반드시 `merge(local.required_tags)` 패턴을 사용해야 합니다.**

✅ **올바른 방법:**
```hcl
resource "aws_ecr_repository" "atlantis" {
  name = "atlantis"

  tags = merge(
    local.required_tags,
    {
      Name      = "ecr-atlantis"
      Component = "atlantis"
    }
  )
}
```

❌ **잘못된 방법:**
```hcl
resource "aws_ecr_repository" "atlantis" {
  name = "atlantis"

  tags = {
    Name        = "ecr-atlantis"
    Owner       = "platform-team"  # 개별 태그 하드코딩 금지
    Environment = "prod"
  }
}
```

**필수 태그 목록:**
- `Owner`: 리소스 소유 팀
- `CostCenter`: 비용 센터
- `Environment`: 환경 (dev/staging/prod)
- `Lifecycle`: 리소스 수명주기 (permanent/temporary)
- `DataClass`: 데이터 분류 (public/internal/confidential/restricted)
- `Service`: 서비스 이름

### 2. KMS Encryption (KMS 암호화)

**모든 암호화는 반드시 고객 관리형 KMS 키를 사용해야 합니다.**

✅ **올바른 방법:**
```hcl
resource "aws_ecr_repository" "example" {
  name = "example"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key        = aws_kms_key.ecr.arn
  }
}
```

❌ **잘못된 방법:**
```hcl
resource "aws_ecr_repository" "example" {
  name = "example"

  encryption_configuration {
    encryption_type = "AES256"  # AWS 관리형 키 사용 금지
  }
}
```

**적용 대상:**
- ECR repositories
- S3 buckets
- RDS instances
- EBS volumes
- 기타 암호화 지원 리소스

### 3. Naming Conventions (네이밍 컨벤션)

**리소스와 변수는 일관된 네이밍 컨벤션을 따라야 합니다.**

#### 리소스 이름: kebab-case
```hcl
resource "aws_ecr_repository" "atlantis" {
  name = "atlantis"  # ✅ 단일 단어
}

resource "aws_kms_key" "ecr_atlantis" {
  description = "KMS key for ECR Atlantis encryption"
  # Resource name in AWS: "ecr-atlantis"  # ✅ kebab-case
}
```

❌ **잘못된 예:**
```hcl
name = "ecrAtlantis"     # camelCase 금지
name = "ECR_Atlantis"    # UPPER_SNAKE_CASE 금지
name = "ecr_atlantis"    # snake_case 금지 (리소스는 kebab-case)
```

#### 변수/로컬 이름: snake_case
```hcl
variable "aws_region" {        # ✅ snake_case
  type = string
}

locals {
  required_tags = {            # ✅ snake_case
    Owner = var.owner
  }
}
```

❌ **잘못된 예:**
```hcl
variable "awsRegion" { }       # camelCase 금지
variable "aws-region" { }      # kebab-case 금지 (변수는 snake_case)
```

### 4. No Hardcoded Secrets (민감정보 하드코딩 금지)

**패스워드, API 키, 시크릿은 절대 하드코딩하지 않습니다.**

✅ **올바른 방법:**
```hcl
resource "aws_db_instance" "example" {
  username = var.db_username
  password = var.db_password  # 변수 또는 Secrets Manager 사용
}
```

❌ **잘못된 방법:**
```hcl
resource "aws_db_instance" "example" {
  username = "admin"
  password = "MyP@ssw0rd123"  # 하드코딩 금지!
}
```

**금지 패턴:**
- `password = "..."`
- `secret = "..."`
- `api_key = "..."`
- `access_key = "..."`
- `secret_key = "..."`

**허용 패턴:**
- `password = var.db_password`
- `password = data.aws_secretsmanager_secret_version.db.secret_string`
- `password = random_password.db.result`

## 🟡 IMPORTANT: 강력 권장 사항

### 5. Terraform Formatting

**코드 작성 후 자동으로 `terraform fmt` 적용**

```hcl
# 들여쓰기는 2칸
resource "aws_ecr_repository" "atlantis" {
  name                 = "atlantis"
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key        = aws_kms_key.ecr.arn
  }
}
```

### 6. Resource Documentation

**중요 리소스에는 주석으로 목적 설명**

```hcl
# ECR repository for Atlantis Docker images
# Used by ECS tasks for Terraform automation
resource "aws_ecr_repository" "atlantis" {
  name = "atlantis"
  # ...
}
```

### 7. KMS Key Rotation

**KMS 키는 자동 로테이션 활성화**

```hcl
resource "aws_kms_key" "example" {
  description             = "KMS key for..."
  deletion_window_in_days = 30
  enable_key_rotation     = true  # ✅ 필수
}
```

## 클로드 작업 플로우

Terraform 코드를 작성할 때 다음 순서를 따릅니다:

1. **리소스 생성 시:**
   - 태그: `merge(local.required_tags, {...})` 자동 적용
   - 암호화: KMS 키 사용 확인
   - 네이밍: kebab-case (리소스), snake_case (변수) 확인

2. **코드 작성 후:**
   - `terraform fmt` 자동 적용
   - 민감정보 하드코딩 체크
   - 주석 추가 (복잡한 로직의 경우)

3. **검증:**
   - 작성한 코드가 위 규칙들을 모두 준수하는지 자체 검증
   - 필요시 `scripts/validators/` 스크립트 실행 권장

## 검증 스크립트

수동으로 검증이 필요한 경우:

```bash
# 태그 검증
./scripts/validators/check-tags.sh

# 암호화 검증
./scripts/validators/check-encryption.sh

# 네이밍 검증
./scripts/validators/check-naming.sh

# 전체 검증
./scripts/validators/check-*.sh
```

## 참고 문서

- `docs/infrastructure_governance.md`: 상세 거버넌스 정책
- `docs/infrastructure_pr.md`: PR 워크플로우 및 체크리스트
- `terraform/atlantis/variables.tf`: 태그 변수 정의 참고
