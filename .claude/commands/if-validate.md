# Infrastructure Validation Command

Terraform 코드의 거버넌스 준수 여부를 검증합니다.

## 사용법

```
/if:validate [path] [options]
/if:validate --all
/if:validate --fix
```

## 옵션

- `--all`: 전체 프로젝트 검증
- `--fix`: 자동 수정 가능한 항목 수정
- `--security`: tfsec/checkov 보안 스캔 포함
- `--cost`: Infracost 비용 분석 포함
- `--report`: 상세 보고서 생성

## 검증 항목

### 🔴 CRITICAL (필수 준수)

1. **Required Tags**
   ```hcl
   # ✅ 올바른 방법
   tags = merge(local.required_tags, { Name = "..." })

   # ❌ 잘못된 방법
   tags = { Owner = "..." }  # 개별 태그 금지
   ```

2. **KMS Encryption**
   ```hcl
   # ✅ 올바른 방법
   encryption_configuration {
     encryption_type = "KMS"
     kms_key = aws_kms_key.xxx.arn
   }

   # ❌ 잘못된 방법
   encryption_type = "AES256"  # AWS 관리형 키 금지
   ```

3. **Naming Convention**
   - 리소스명: `kebab-case` (예: `ecr-atlantis`)
   - 변수/로컬: `snake_case` (예: `aws_region`)

4. **No Hardcoded Secrets**
   - `password = "..."` 금지
   - `secret_key = "..."` 금지

### 🟡 IMPORTANT (강력 권장)

5. **KMS Key Rotation**
   ```hcl
   enable_key_rotation = true
   ```

6. **Terraform Formatting**
   ```bash
   terraform fmt
   ```

7. **Resource Documentation**
   - 중요 리소스에 주석 추가

## 검증 스크립트

```bash
# 개별 검증기 (governance/ 디렉토리)
./governance/scripts/validators/check-tags.sh <path>
./governance/scripts/validators/check-encryption.sh <path>
./governance/scripts/validators/check-naming.sh <path>
./governance/scripts/validators/check-tfsec.sh <path>
./governance/scripts/validators/check-checkov.sh <path>

# 단일 파일 검증
./governance/scripts/validators/validate-terraform-file.sh <file.tf>

# OPA 정책 검증 (Conftest)
conftest test tfplan.json --config governance/configs/conftest.toml
```

## OPA 정책 참조 (governance/policies/)

```bash
# 태그 정책 확인
cat governance/policies/tagging/required_tags.rego

# 네이밍 정책 확인
cat governance/policies/naming/resource_naming.rego

# 보안 그룹 정책 확인
cat governance/policies/security_groups/security_group_rules.rego

# 공개 리소스 정책 확인
cat governance/policies/public_resources/public_access.rego
```

## 설정 파일 위치

| 도구 | 설정 파일 |
|------|-----------|
| Conftest (OPA) | `governance/configs/conftest.toml` |
| tfsec | `governance/configs/tfsec/config.yml` |
| Checkov | `governance/configs/checkov.yml` |
| Infracost | `governance/configs/infracost.yml` |

## 출력 형식

```
🔍 Infrastructure Governance Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 Scanning: terraform/environments/prod/

🔴 CRITICAL Issues:
  ❌ terraform/environments/prod/ecr/main.tf:15
     Missing merge(local.required_tags)

  ❌ terraform/environments/prod/s3/main.tf:8
     Using AES256 instead of KMS

🟡 WARNINGS:
  ⚠️ terraform/environments/prod/kms/main.tf:3
     enable_key_rotation not set

✅ PASSED: 45/47 files
❌ FAILED: 2/47 files

📊 Summary:
  - Tags: 2 issues
  - Encryption: 1 issue
  - Naming: 0 issues
  - Secrets: 0 issues
```

## 자동 수정 (`--fix`)

자동 수정 가능한 항목:
- `terraform fmt` 적용
- `enable_key_rotation = true` 추가
- 주석 형식 정리

수동 수정 필요 항목:
- 태그 패턴 변경
- 암호화 타입 변경
- 하드코딩된 시크릿

## 예제

```bash
# 현재 디렉토리 검증
/if:validate

# 특정 모듈 검증
/if:validate terraform/modules/ecs-service

# 전체 검증 + 보안 스캔
/if:validate --all --security

# 자동 수정 + 보고서
/if:validate --fix --report
```

## CI/CD 통합

PR 시 자동 실행:
- `.github/workflows/terraform-plan.yml`
- `.github/workflows/infra-checks.yml`

## 관련 커맨드

- `/if:module` - 모듈 생성/관리
- `/if:atlantis` - Atlantis 작업
- `/if:shared` - 공유 리소스 관리
