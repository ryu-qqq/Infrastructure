# Checkov Policy Guide

> **Checkov 정책 검증 가이드 및 Skip 규칙 관리**
>
> 이 문서는 Checkov를 사용한 Terraform 코드 정책 검증과 Skip 규칙 관리를 위한 가이드입니다.

## 📋 목차

- [개요](#개요)
- [Checkov란](#checkov란)
- [설정 파일 구조](#설정-파일-구조)
- [지원하는 Compliance Framework](#지원하는-compliance-framework)
- [Skip 규칙 관리](#skip-규칙-관리)
- [로컬 실행 방법](#로컬-실행-방법)
- [CI/CD 통합](#cicd-통합)
- [문제 해결 가이드](#문제-해결-가이드)
- [참고 자료](#참고-자료)

---

## 개요

### 목적

Checkov를 통해 인프라 코드에 대한 다음을 보장합니다:

- **보안 표준 준수**: CIS AWS Foundations Benchmark 기반 보안 검증
- **규정 준수**: PCI-DSS, HIPAA, ISO 27001 등 컴플라이언스 요구사항 충족
- **정책 자동화**: 거버넌스 정책의 자동 검증 및 강제
- **보안 취약점 사전 탐지**: 배포 전 보안 이슈 식별 및 수정

### Checkov vs tfsec

| 특징 | Checkov | tfsec |
|------|---------|-------|
| **주요 초점** | 정책 준수, 규정 준수 | 보안 취약점 탐지 |
| **Framework** | CIS, PCI-DSS, HIPAA, ISO 27001 | OWASP, AWS 보안 모범 사례 |
| **검증 범위** | Terraform, CloudFormation, K8s 등 | Terraform 전용 |
| **Skip 방식** | 정책 파일 기반 | 주석 기반 + 설정 파일 |
| **사용 사례** | 규정 준수 감사, 정책 검증 | 보안 스캔, 취약점 탐지 |

**권장 사용**: 두 도구를 모두 사용하여 보안과 규정 준수를 동시에 보장합니다.

---

## Checkov란

### 주요 기능

1. **다중 프레임워크 지원**
   - CIS AWS Foundations Benchmark
   - PCI-DSS (Payment Card Industry Data Security Standard)
   - HIPAA (Health Insurance Portability and Accountability Act)
   - ISO/IEC 27001 (Information Security Management)

2. **포괄적인 검증**
   - 암호화 표준 (KMS, at-rest, in-transit)
   - 접근 제어 (IAM 정책, 보안 그룹)
   - 로깅 및 모니터링
   - 네트워크 보안
   - 시크릿 탐지

3. **다양한 출력 형식**
   - CLI (사람이 읽기 쉬운 형식)
   - JSON (자동화 및 파싱)
   - SARIF (GitHub Security 탭 통합)
   - JUnit XML (테스트 결과 추적)

---

## 설정 파일 구조

### `.checkov.yml` 구조

> **참고**: 이 프로젝트의 `.checkov.yml` 파일은 CI/CD 유연성을 위해 최소 설정만 포함합니다.
> 대부분의 옵션(`output`, `severity`, `parallel` 등)은 `scripts/validators/check-checkov.sh` 스크립트에서 CLI 플래그로 관리됩니다.

```yaml
# Framework 설정
# 'terraform' 프레임워크는 CIS AWS, PCI-DSS, HIPAA, ISO27001 등의 주요 규정 준수 검사를 포함합니다.
framework:
  - terraform

# 스캔 대상 디렉토리
directory:
  - terraform/atlantis
  - terraform/logging
  - terraform/monitoring
  - terraform/network
  - terraform/kms
  - terraform/secrets
  - terraform/modules

# 제외 경로
skip-path:
  - terraform/.terraform/**
  - terraform/**/test/**
  - terraform/**/examples/**
  - "**/*.tfvars"  # Variable files may contain sensitive data patterns

# Skip 할 체크 (정당한 사유와 함께 신중하게 사용)
skip-check:
  # 예시: S3 버킷 버저닝 - 임시 버킷에는 불필요
  # Justification: 로그 수집용 임시 버킷으로 버저닝 불필요
  # Review Date: 2025-04-01
  # Approved By: platform-team
  # - CKV_AWS_21

# Soft fail 설정
# CI에서는 스크립트가 심각도(CRITICAL/HIGH/MEDIUM)에 따라 실패를 결정합니다.
soft-fail: false

# Compact output
compact: true

# Quiet mode
quiet: false
```

#### CLI 플래그로 관리되는 옵션

다음 옵션들은 `check-checkov.sh` 스크립트에서 CLI 플래그로 제어됩니다:

```bash
# 출력 형식
--output json                  # JSON 출력

# 심각도 필터링
--soft-fail                    # 실패 처리 방식 (스크립트에서 관리)

# 성능 옵션
--download-external-modules false  # 외부 모듈 다운로드 비활성화

# 시크릿 스캔
--enable-secret-scan-all-files    # 전체 파일 시크릿 스캔 (필요시)
```

**왜 이렇게 분리했나요?**
- **유연성**: 로컬과 CI에서 다른 옵션 사용 가능
- **관리 용이성**: 스크립트 수정으로 옵션 변경 가능 (설정 파일 재배포 불필요)
- **호환성**: Checkov 버전 업데이트 시 호환성 문제 최소화

---

## 지원하는 Compliance Framework

### 1. CIS AWS Foundations Benchmark v1.4.0

CIS (Center for Internet Security) AWS 보안 모범 사례를 검증합니다.

**주요 검증 항목**:
- IAM 사용자 및 역할 보안
- S3 버킷 암호화 및 접근 제어
- VPC 및 네트워크 보안 그룹 설정
- CloudTrail 로깅 활성화
- KMS 키 관리

**체크 ID 형식**: `CKV_AWS_*`

예시:
- `CKV_AWS_19`: S3 버킷 암호화 필수
- `CKV_AWS_21`: S3 버킷 버저닝 활성화
- `CKV_AWS_53`: S3 버킷 로깅 활성화

### 2. PCI-DSS v3.2.1

신용카드 정보 보호를 위한 PCI-DSS 표준을 검증합니다.

**주요 검증 항목**:
- 전송 중 데이터 암호화 (TLS/SSL)
- 저장 데이터 암호화 (at-rest encryption)
- 접근 제어 및 인증
- 로깅 및 감사 추적

### 3. HIPAA

의료 정보 보호를 위한 HIPAA 규정을 검증합니다.

**주요 검증 항목**:
- PHI (Protected Health Information) 암호화
- 접근 로그 및 감사 추적
- 백업 및 복구 메커니즘
- 네트워크 격리 및 보안

### 4. ISO/IEC 27001

정보 보안 관리 시스템(ISMS) 표준을 검증합니다.

**주요 검증 항목**:
- 정보 자산 보호
- 접근 제어 및 권한 관리
- 암호화 및 키 관리
- 로깅 및 모니터링

---

## Skip 규칙 관리

### Skip 규칙 추가 프로세스

1. **정당성 확인**: Skip이 정말 필요한지 검토
2. **문서화**: Skip 사유를 명확히 기록
3. **승인**: 보안 팀 또는 플랫폼 팀 승인
4. **주기적 검토**: 분기별 Skip 규칙 재검토

### Skip 규칙 형식

```yaml
skip-check:
  # [체크 ID] [사유]
  # Justification: [상세한 정당성 설명]
  # Review Date: [다음 검토 날짜]
  # Approved By: [승인자]

  # 예시 1: S3 버킷 버저닝 - 로그 수집 버킷
  # Justification: 로그 수집용 임시 버킷으로 버저닝 불필요
  # Review Date: 2025-04-01
  # Approved By: platform-team
  - CKV_AWS_21  # S3 bucket versioning

  # 예시 2: RDS 퍼블릭 접근 - 개발 환경
  # Justification: 개발 환경 DB로 제한적 퍼블릭 접근 허용
  # Review Date: 2025-04-01
  # Approved By: security-team
  # - CKV_AWS_17  # RDS public access (프로덕션에서는 절대 Skip 금지!)
```

### Skip 규칙 카테고리

#### ✅ 허용되는 Skip 사유

1. **아키텍처적 제약**
   - 특정 서비스 특성상 정책 적용 불가능
   - AWS 서비스 제한사항으로 인한 예외

   ```yaml
   # Lambda 환경변수 암호화 - VPC 밖에서 실행되는 Lambda
   - CKV_AWS_173  # Lambda environment encryption
   ```

2. **비즈니스 요구사항**
   - 성능상의 이유로 예외 필요
   - 비용 최적화를 위한 선택적 적용

   ```yaml
   # S3 버킷 버저닝 - 대용량 로그 스토리지
   - CKV_AWS_21  # S3 versioning (cost optimization)
   ```

3. **임시 버킷/리소스**
   - 수명이 짧은 임시 리소스
   - 테스트 또는 개발 환경

   ```yaml
   # S3 로깅 - 임시 버킷
   - CKV_AWS_18  # S3 bucket logging
   ```

#### ❌ 금지되는 Skip

다음 체크는 **절대** Skip할 수 없습니다:

```yaml
# 🚨 프로덕션 환경에서 Skip 금지
# - CKV_AWS_17  # RDS 퍼블릭 접근
# - CKV_AWS_19  # S3 암호화
# - CKV_AWS_20  # S3 퍼블릭 접근 차단
# - CKV_AWS_40  # IAM 정책 와일드카드 금지
# - CKV_AWS_61  # IAM 정책 전체 권한 금지
```

### In-line Skip (코드 주석)

특정 리소스에만 Skip을 적용할 때 사용:

```hcl
# checkov:skip=CKV_AWS_21:로그 수집용 임시 버킷으로 버저닝 불필요
resource "aws_s3_bucket" "logs" {
  bucket = "my-logs-bucket"
  # ... 생략
}

# 여러 체크 Skip
# checkov:skip=CKV_AWS_18:임시 버킷으로 로깅 불필요
# checkov:skip=CKV_AWS_21:버저닝 불필요
resource "aws_s3_bucket" "temp" {
  bucket = "temp-bucket"
  # ... 생략
}
```

**주의사항**:
- In-line skip은 특정 리소스에만 적용
- 글로벌 설정은 `.checkov.yml` 사용
- Skip 사유를 항상 명시

---

## 로컬 실행 방법

### 1. Checkov 설치

```bash
# pip을 통한 설치
pip install checkov

# Homebrew를 통한 설치 (macOS)
brew install checkov

# Docker를 통한 실행
docker pull bridgecrew/checkov
```

### 2. 로컬 스캔 실행

#### 기본 스캔

```bash
# 전체 terraform 디렉토리 스캔
checkov -d terraform/ --config-file .checkov.yml

# 특정 디렉토리 스캔
checkov -d terraform/network --config-file .checkov.yml

# 단일 파일 스캔
checkov -f terraform/network/main.tf
```

#### 다양한 출력 형식

```bash
# JSON 출력
checkov -d terraform/ --config-file .checkov.yml --output json

# SARIF 출력 (GitHub Security 탭용)
checkov -d terraform/ --config-file .checkov.yml --output sarif

# 결과를 파일로 저장
checkov -d terraform/ --config-file .checkov.yml --output json --output-file-path checkov-results.json
```

#### 특정 프레임워크만 검증

```bash
# CIS AWS만 검증
checkov -d terraform/ --framework cis_aws

# PCI-DSS + HIPAA 검증
checkov -d terraform/ --framework pci --framework hipaa
```

### 3. 검증 스크립트 사용

```bash
# 전체 검증 실행
./scripts/validators/check-checkov.sh

# 특정 디렉토리 검증
./scripts/validators/check-checkov.sh terraform/network
```

---

## CI/CD 통합

### GitHub Actions 통합

Checkov는 `terraform-plan.yml` 워크플로우에 통합되어 있습니다.

#### 워크플로우 흐름

```yaml
- name: Run Governance Validators
  run: |
    ./scripts/validators/check-tags.sh
    ./scripts/validators/check-encryption.sh
    ./scripts/validators/check-naming.sh
    ./scripts/validators/check-tfsec.sh
    ./scripts/validators/check-checkov.sh  # ✅ Checkov 추가
```

#### PR 코멘트 통합

Checkov 결과는 PR 코멘트에 자동으로 추가됩니다:

```markdown
#### 🔐 Policy Compliance (checkov)

**Compliance Status:**
✅ CIS AWS Foundations Benchmark
✅ PCI-DSS v3.2.1
⚠️ HIPAA - 2 medium issues
✅ ISO/IEC 27001

**Issues:**
- 🚨 Critical: 0
- ❌ High: 0
- ⚠️ Medium: 2
- ℹ️ Low: 5

⚠️ **Action Required:** Medium severity issues found
```

### Git Hooks 통합

이 프로젝트는 `scripts/hooks/` 디렉토리의 Git hooks를 사용합니다.

```bash
# Git hooks 설치
./scripts/setup-hooks.sh

# Pre-commit hook에서 자동 실행:
# 1. terraform fmt
# 2. 민감 정보 스캔
# 3. terraform validate
# 4. OPA 정책 검증 (conftest)
```

**참고**: Checkov는 실행 시간이 길어 pre-commit hook에 포함되지 않습니다. 대신 다음에서 실행됩니다:
- **GitHub Actions**: PR 생성 시 자동 실행
- **수동 실행**: `./scripts/validators/check-checkov.sh`

**📖 자세한 내용**: [Scripts README](../../scripts/README.md)

---

## 문제 해결 가이드

### 일반적인 문제

#### 1. CRITICAL/HIGH 이슈 발견 시

**단계**:
1. 결과 파일 확인: `cat checkov-results.json | jq`
2. 이슈 상세 내용 확인
3. 수정 방법 검토:
   - 코드 수정으로 해결 (권장)
   - Skip 규칙 추가 (정당한 사유 필요)

**예시: S3 암호화 누락**

```hcl
# ❌ Before: 암호화 미적용
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"
}

# ✅ After: KMS 암호화 적용
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}
```

#### 2. False Positive 처리

일부 체크가 false positive일 경우:

```yaml
# .checkov.yml에 추가
skip-check:
  # False positive: 특정 리소스에만 해당하는 체크
  # Justification: [상세 설명]
  - CKV_AWS_XXX
```

또는 코드에서 직접 Skip:

```hcl
# checkov:skip=CKV_AWS_XXX:False positive - 실제로는 올바르게 구성됨
resource "aws_xxx" "example" {
  # ...
}
```

#### 3. 느린 스캔 속도

**해결 방법**:

```yaml
# .checkov.yml 최적화
enable-parallel: true
download-external-modules: false  # 외부 모듈 다운로드 비활성화
skip-path:
  - terraform/.terraform/**  # .terraform 디렉토리 제외
```

#### 4. 시크릿 탐지 오탐 (Secrets Detection False Positive)

```yaml
# 시크릿 스캔 특정 패턴 제외
skip-secrets-scan:
  - BC_GIT_1  # 일반적인 Git secrets
```

#### 5. CKV_AWS_2 에러 (Dynamic Block 파싱 오류) - ✅ 해결됨

**에러 메시지**:
```
[ERROR] Failed to run check CKV_AWS_2 on /modules/alb/main.tf:aws_lb_listener.http["default"]
KeyError: 0
protocol = default_action['redirect'][0].get('protocol')
```

**원인**:
- CKV_AWS_2는 ALB 리스너가 HTTPS를 사용하는지 검증하는 체크
- Checkov가 Terraform의 `dynamic "redirect"` 블록을 잘못 파싱
- Dynamic block을 리스트로 예상하고 `[0]` 인덱스 접근 시도하나, dynamic block은 for_each로 관리되므로 직접 인덱스 접근 불가능

**적용된 해결 방법**:

`.checkov.yml`에 skip-check 추가 (False positive 방지):

```yaml
skip-check:
  # ALB HTTPS Protocol Check - Checkov dynamic block parsing bug
  # Justification: CKV_AWS_2 fails to parse dynamic redirect blocks in ALB listeners
  # Issue: Checkov tries to access redirect[0] but dynamic blocks use for_each
  # Impact: False positive - actual code properly configures HTTPS redirects
  # Reference: docs/governance/CHECKOV_POLICY_GUIDE.md - Troubleshooting section
  - CKV_AWS_2  # ALB listener protocol HTTPS
```

**검증 결과**:
- ✅ stderr 에러 메시지 제거됨
- ✅ JSON 출력 정상
- ✅ 스크립트 정상 종료 (Exit code 0)
- ✅ 실제 ALB HTTPS 설정은 올바르게 구성됨 (`terraform/modules/alb/main.tf`)

**참고**:
- 이는 Terraform 코드 문제가 아닌 Checkov의 파싱 버그입니다
- Skip 규칙 추가로 False positive를 제거했습니다
- 실제 HTTPS 리디렉션은 코드에서 올바르게 구현되어 있습니다
- Checkov 버전 업데이트 시 이 skip 규칙 제거 검토 필요

---

## 주요 체크 항목 및 수정 가이드

### 암호화 관련

#### CKV_AWS_19: S3 버킷 암호화

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.example.arn
    }
  }
}
```

#### CKV_AWS_7: RDS 암호화

```hcl
resource "aws_db_instance" "example" {
  storage_encrypted = true
  kms_key_id       = aws_kms_key.rds.arn
  # ...
}
```

### 접근 제어

#### CKV_AWS_20: S3 버킷 퍼블릭 접근 차단

```hcl
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

#### CKV_AWS_17: RDS 퍼블릭 접근 금지

```hcl
resource "aws_db_instance" "example" {
  publicly_accessible = false
  # ...
}
```

### 로깅 및 모니터링

#### CKV_AWS_18: S3 버킷 로깅

```hcl
resource "aws_s3_bucket_logging" "example" {
  bucket = aws_s3_bucket.example.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}
```

#### CKV_AWS_23: Security Group 로깅

```hcl
# VPC Flow Logs 활성화
resource "aws_flow_log" "example" {
  vpc_id          = aws_vpc.example.id
  traffic_type    = "ALL"
  log_destination = aws_s3_bucket.flow_logs.arn
}
```

---

## 참고 자료

### 공식 문서

- [Checkov 공식 문서](https://www.checkov.io/)
- [Checkov Policy Index](https://www.checkov.io/5.Policy%20Index/terraform.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)

### 관련 내부 문서

- [Infrastructure Governance](./infrastructure_governance.md) - 전체 거버넌스 표준
- [Security Scan Report Template](./SECURITY_SCAN_REPORT_TEMPLATE.md) - 보안 스캔 리포트 작성
- [Naming Convention](./NAMING_CONVENTION.md) - 리소스 네이밍 규칙
- [Tagging Standards](./TAGGING_STANDARDS.md) - 태그 표준

### Checkov 체크 카탈로그

주요 AWS 체크 항목:

| 체크 ID | 설명 | 심각도 | 카테고리 |
|---------|------|--------|----------|
| CKV_AWS_19 | S3 버킷 암호화 | CRITICAL | 암호화 |
| CKV_AWS_21 | S3 버킷 버저닝 | MEDIUM | 데이터 보호 |
| CKV_AWS_18 | S3 버킷 로깅 | MEDIUM | 로깅 |
| CKV_AWS_20 | S3 퍼블릭 접근 차단 | CRITICAL | 접근 제어 |
| CKV_AWS_7 | RDS 암호화 | CRITICAL | 암호화 |
| CKV_AWS_17 | RDS 퍼블릭 접근 금지 | CRITICAL | 접근 제어 |
| CKV_AWS_40 | IAM 정책 와일드카드 금지 | HIGH | IAM |
| CKV_AWS_61 | IAM 정책 전체 권한 금지 | CRITICAL | IAM |

전체 체크 목록: https://www.checkov.io/5.Policy%20Index/terraform.html

---

## 버전 이력

| 버전 | 날짜 | 작성자 | 변경 내역 |
|------|------|--------|-----------|
| 1.0 | 2025-10-17 | Platform Team | 초기 작성 - Checkov 정책 가이드 및 Skip 규칙 |

---

## 연락처

문의사항이나 Skip 규칙 승인 요청:
- **Platform Team**: platform-team@example.com
- **Security Team**: security-team@example.com
