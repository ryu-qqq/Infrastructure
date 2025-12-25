# ECR AES256 암호화 정책 예외

## 개요

이 문서는 ECR 모듈에서 AES256 암호화를 허용하는 정책 예외 사항을 명시합니다.

## 예외 정보

| 항목 | 내용 |
|------|------|
| **예외 ID** | PE-ECR-001 |
| **승인일** | 2024-12-25 |
| **적용 범위** | terraform/modules/ecr |
| **예외 유형** | 보안 정책 예외 |
| **상태** | 활성 |

## 배경

### 기존 정책
CLAUDE.md 및 infrastructure_governance.md에 따르면:
> "ALL encryption MUST use customer-managed KMS keys (never use AES256)"

### 예외 필요성
기존 ECR 리포지토리(예: FileFlow)가 AES256 암호화를 사용하고 있어, Terraform으로 해당 리소스를 관리(import)하기 위해서는 AES256 암호화 유형을 허용해야 합니다.

## 예외 조건

### 허용되는 경우
1. **기존 리소스 Import**: AES256으로 생성된 기존 ECR 리포지토리를 Terraform으로 가져올 때
2. **레거시 호환성**: 마이그레이션 기간 동안 기존 시스템과의 호환성 유지가 필요할 때

### 허용되지 않는 경우
1. **신규 리포지토리 생성**: 새로운 ECR 리포지토리는 반드시 KMS 암호화 사용
2. **보안 민감 데이터**: confidential 데이터 분류 리소스는 KMS 필수

## 안전장치

### 1. Terraform Precondition
`encryption_type`이 "KMS"인 경우 `kms_key_arn`이 필수로 지정되도록 precondition이 추가되었습니다.

```hcl
lifecycle {
  precondition {
    condition     = var.encryption_type != "KMS" || var.kms_key_arn != null
    error_message = "encryption_type이 'KMS'인 경우 kms_key_arn 변수도 반드시 설정해야 합니다."
  }
}
```

### 2. Governance Validation
`check-encryption.sh` 스크립트가 수정되어:
- AES256 사용 시 **경고(WARNING)** 출력 (에러 아님)
- CI/CD 파이프라인이 실패하지 않음
- KMS 마이그레이션을 권장하는 메시지 표시

### 3. 문서화
- README.md에 암호화 옵션 명확히 문서화
- 신규 리포지토리에 KMS 권장 사항 명시

## 향후 계획

### 단기 (1-3개월)
- [ ] 기존 AES256 사용 ECR 리포지토리 목록 작성
- [ ] 각 리포지토리별 KMS 마이그레이션 영향 분석

### 중기 (3-6개월)
- [ ] 비프로덕션 환경 ECR 리포지토리 KMS 마이그레이션
- [ ] 마이그레이션 프로세스 문서화

### 장기 (6-12개월)
- [ ] 프로덕션 환경 ECR 리포지토리 KMS 마이그레이션
- [ ] 정책 예외 종료 및 KMS 전용으로 전환

## 관련 파일

- `terraform/modules/ecr/main.tf` - ECR 모듈 메인 코드
- `terraform/modules/ecr/variables.tf` - 암호화 관련 변수
- `terraform/modules/ecr/README.md` - 모듈 문서
- `governance/scripts/validators/check-encryption.sh` - 암호화 검증 스크립트

## 검토 이력

| 날짜 | 검토자 | 내용 |
|------|--------|------|
| 2024-12-25 | AI Review (Gemini + CodeRabbit) | 정책 충돌 감지 및 예외 승인 |

## 연락처

정책 예외에 대한 문의: Platform Team
