# Terraform Bootstrap Module

이 모듈은 Terraform State 백엔드 인프라를 구축합니다. 모든 Terraform 프로젝트가 사용하는 **공통 State 저장소**입니다.

## 📋 목적

다른 Terraform 모듈들이 사용할 원격 State 백엔드 리소스를 생성:
- **S3 버킷**: Terraform state 파일 저장
- **DynamoDB 테이블**: State locking 및 일관성 체크
- **KMS 키**: State 파일 암호화

## 🏗️ 생성되는 리소스

### 1. S3 Bucket (`prod-connectly`)
- ✅ **버전 관리**: State 파일 히스토리 및 롤백 지원
- ✅ **KMS 암호화**: 고객 관리형 키로 데이터 암호화
- ✅ **수명주기 정책**: 
  - 90일 후 이전 버전을 Glacier로 전환
  - 365일 후 이전 버전 삭제
- ✅ **퍼블릭 액세스 차단**: 모든 퍼블릭 액세스 금지
- ✅ **버킷 정책**: HTTPS 전송 강제, 암호화되지 않은 업로드 거부

### 2. DynamoDB Table (`prod-connectly-tf-lock`)
- ✅ **On-demand 요금제**: 사용량 기반 과금
- ✅ **Point-in-time Recovery**: 재해 복구 지원
- ✅ **LockID 파티션 키**: Terraform 표준 스키마

### 3. KMS Key (`terraform-state-prod`)
- ✅ **자동 키 로테이션**: 매년 자동 교체
- ✅ **30일 삭제 대기**: 실수 방지
- ✅ **키 정책**: S3 서비스 및 계정 루트만 접근 허용

## ⚠️ 중요: Bootstrap의 특수성

### Chicken-Egg Problem

이 모듈은 **로컬 백엔드**를 사용합니다:
```hcl
backend "local" {
  path = "terraform.tfstate"
}
```

**이유**: State를 저장할 S3 버킷을 생성하는 모듈이므로, S3 백엔드를 사용할 수 없습니다.

### State 파일 관리

- ✅ **로컬 state 파일 커밋 금지**: `.gitignore`에 추가됨
- ✅ **안전한 보관**: 로컬 백업 또는 별도 S3 버킷에 수동 저장 권장
- ✅ **팀 협업**: 한 사람만 bootstrap 리소스 관리 (충돌 방지)

## 🚀 사용 방법

### Option 1: 기존 리소스 Import (권장)

**현재 상황**: `prod-connectly` 버킷과 `prod-connectly-tf-lock` 테이블이 이미 존재

```bash
cd terraform/bootstrap

# 1. Terraform 초기화
terraform init

# 2. 기존 리소스 Import (상세 가이드는 IMPORT.md 참조)
terraform import aws_s3_bucket.terraform_state prod-connectly
terraform import aws_dynamodb_table.terraform_lock prod-connectly-tf-lock

# 3. Plan으로 drift 확인 (No changes가 나와야 함)
terraform plan

# 4. 필요한 경우 apply (KMS 키 등 신규 리소스 생성)
terraform apply
```

**상세 절차**: [IMPORT.md](./IMPORT.md) 참조

### Option 2: 새 환경 구축

**새 AWS 계정/리전에서 처음부터 생성**

```bash
cd terraform/bootstrap

# 1. 변수 파일 생성 (선택 사항)
cat > terraform.tfvars <<EOF
environment             = "dev"
state_bucket_name       = "dev-connectly"
state_lock_table_name   = "dev-connectly-tf-lock"
aws_region             = "ap-northeast-2"
EOF

# 2. Terraform 초기화 및 적용
terraform init
terraform plan
terraform apply
```

## 📊 생성 후 다른 모듈 설정

Bootstrap 완료 후, 다른 Terraform 모듈에서 사용:

```hcl
# terraform/atlantis/provider.tf
terraform {
  backend "s3" {
    bucket         = "prod-connectly"
    key            = "atlantis/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "prod-connectly-tf-lock"
    encrypt        = true
  }
}
```

## 🔒 보안 고려사항

1. **로컬 State 보호**
   - Bootstrap state 파일을 안전한 곳에 백업
   - 절대 Git에 커밋하지 않음
   - 필요 시 암호화된 저장소에 보관

2. **최소 권한 원칙**
   - Bootstrap 실행 시 Admin 권한 필요
   - 일반 개발자는 Read-only 접근만 제공

3. **감사 추적**
   - S3 버킷 로깅 활성화 권장
   - CloudTrail로 API 호출 기록

## 📁 파일 구조

```
terraform/bootstrap/
├── provider.tf         # Terraform 설정 (local backend)
├── variables.tf        # 입력 변수 및 locals
├── s3.tf              # State 버킷 생성
├── dynamodb.tf        # Lock 테이블 생성
├── kms.tf             # 암호화 키 생성
├── outputs.tf         # 출력 (다른 모듈에서 사용)
├── .gitignore         # State 파일 제외
├── README.md          # 이 문서
└── IMPORT.md          # Import 상세 가이드
```

## 🏷️ 거버넌스 준수

이 모듈은 조직의 인프라 거버넌스 표준을 준수합니다:

- ✅ **Required Tags**: 모든 리소스에 `merge(local.required_tags)` 적용
- ✅ **KMS 암호화**: 고객 관리형 KMS 키 사용 (AES256 금지)
- ✅ **네이밍 컨벤션**: kebab-case (리소스), snake_case (변수)
- ✅ **자동 키 로테이션**: KMS 키 자동 교체 활성화

## 🆘 트러블슈팅

### Import 실패

```bash
Error: resource not found
```

**해결**: AWS 리전 및 리소스 이름 확인
```bash
aws s3 ls | grep prod-connectly
aws dynamodb list-tables --region ap-northeast-2 | grep prod-connectly
```

### Drift 발생 (plan에서 변경사항 발견)

**원인**: Terraform 코드가 실제 리소스와 불일치

**해결**: 
1. 실제 리소스 설정 확인 (AWS Console)
2. Terraform 코드 수정하여 일치시킴
3. 또는 `terraform apply`로 실제 리소스를 코드에 맞춤

### State 파일 손실

**예방**: 
- 정기적으로 로컬 state 파일 백업
- 별도 S3 버킷에 수동 복사 권장

**복구**:
- 백업에서 복원
- 또는 모든 리소스 다시 import

## 📚 참고 문서

- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [DynamoDB State Locking](https://developer.hashicorp.com/terraform/language/settings/backends/s3#dynamodb-state-locking)
- [Import Guide](./IMPORT.md)

## 🎯 완료 기준 (TASK 1-1)

- [x] S3 버킷 생성 (버전관리, 암호화, 수명주기)
- [x] DynamoDB Lock 테이블 생성
- [x] KMS 키 생성 및 권한 설정
- [x] 백엔드 설정 문서화
- [ ] `terraform init` 성공 (Import 후 확인)
- [ ] State lock/unlock 정상 작동 (Import 후 확인)

## 📞 연락처

질문이나 문제 발생 시:
- **Owner**: platform-team
- **Jira**: [IN-103](https://ryuqqq.atlassian.net/browse/IN-103)
