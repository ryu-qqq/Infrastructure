# 거버넌스 및 운영 기준

# 거버넌스 및 운영 기준

이 문서는 Infrastructure Management 프로젝트의 상세 운영 기준을 정의합니다.

## 1. 리포지토리 및 권한 관리

**리포지토리 분리**

- `shared-infra`: 공유 인프라 (VPC, Transit Gateway, 보안 서비스)
- `product-*`: 제품별 인프라 스택
- `modules`: 공용 Terraform 모듈

**승인 규칙**

- `shared-infra` 변경: 플랫폼팀 2인 승인 + 보안 리뷰 필수
- 보안/네트워크 변경: CODEOWNERS에 명시된 추가 승인 필요
- 제품 스택 변경: 해당 제품팀 1인 승인

**명령 제한**

- 허용: `atlantis plan`, `atlantis apply`, `atlantis unlock`
- 금지: `atlantis destroy` (별도 비상 절차 필요)

---

## 2. Terraform State 관리

**State 백엔드 표준**

```hcl
terraform {
  backend "s3" {
    bucket         = "ryuqqq-${var.env}-tfstate"
    key            = "${var.stack}/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
    kms_key_id     = "alias/terraform-state"
  }
}
```

**스택 분리 전략**

- 환경별 분리: dev, staging, prod
- 리전별 분리: ap-northeast-2 (primary), ap-northeast-1 (DR)
- 도메인별 분리: network, security, monitoring, application

**교차 참조 금지**

스택 간 데이터 의존은 Output → SSM Parameter Store → Input 패턴 사용:

```hcl
# 공유 VPC (Output)
output "vpc_id" {
  value = aws_[vpc.shared.id](http://vpc.shared.id)
}

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/shared/network/vpc-id"
  type  = "String"
  value = aws_[vpc.shared.id](http://vpc.shared.id)
}

# 제품 스택 (Input)
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

resource "aws_security_group" "app" {
  vpc_id = [data.aws](http://data.aws)_ssm_parameter.vpc_id.value
}
```

**드리프트 방지**

- PR마다 `terraform plan -detailed-exitcode` 실행
- Exit code가 0 또는 2가 아니면 실패 처리
- 의도치 않은 변경 감지 시 알림

---

## 3. 네트워크 표준

**VPC 설계**

- CIDR: `/16` (예: 10.0.0.0/16)
- 서브넷 계층:
    - Public: `/20` (Multi-AZ)
    - Private: `/19` (Multi-AZ)
    - Data: `/20` (Multi-AZ)

**네이밍 규약**

- VPC: `vpc-{env}-{region}` (예: vpc-prod-apne2)
- Subnet: `subnet-{tier}-{az}` (예: subnet-private-apne2a)
- Security Group: `sg-{svc}-{purpose}` (예: sg-crawler-ecs)

**VPC Endpoints 의무화**

아웃바운드 트래픽 비용 절감을 위해 다음 서비스는 VPC Endpoint 필수:

- S3 (Gateway)
- DynamoDB (Gateway)
- ECR (Interface)
- Secrets Manager (Interface)
- STS (Interface)

**Transit Gateway 표준**

VPC Peering 대신 Transit Gateway를 사용하여 네트워크 연결 단순화

---

## 4. 보안 및 비밀 관리

**KMS 키 분리 전략**

```hcl
# 데이터 클래스별 KMS 키
resource "aws_kms_key" "log" {
  description = "KMS key for CloudWatch Logs encryption"
  key_usage   = "ENCRYPT_DECRYPT"
}

resource "aws_kms_key" "db" {
  description = "KMS key for RDS encryption"
}

resource "aws_kms_key" "s3" {
  description = "KMS key for S3 encryption"
}
```

**Secrets Manager 표준**

- 시크릿 네이밍: `/org/{service}/{env}/{name}`
- 회전 정책: 90일마다 자동 회전
- 만료 알림: 30일 전 알림

**이미지 보안**

- ECR 이미지 스캔 자동화
- 이미지 서명 검증 (Cosign/Notary)
- 퍼블릭 이미지 사용 금지

---

## 5. 로깅 및 모니터링 표준

**LogGroup 네이밍**

```
/org/{service}/{env}/{component}

예시:
/ryuqqq/crawler/prod/api
/ryuqqq/authhub/prod/auth-service
```

**로그 보존 정책**

- CloudWatch Logs: 7~14일
- S3 Archive: 90일 (Standard) → 1년 (IA) → 7년 (Glacier)

**로그 아카이브 파이프라인**

```
CloudWatch Logs → Subscription Filter → Kinesis Firehose → S3
                                                    ↓
                                         OpenSearch / Athena
```

**표준 알람 세트**

애플리케이션 알람:

- 5xx 에러 비율 > 1%
- p95 레이턴시 > 1초
- 에러 로그 패턴 감지
- OOM/컨테이너 재시작
- 큐 적체 (메시지 age > 5분)

인프라 알람:

- CPU > 80%
- 메모리 > 85%
- 디스크 > 80%
- RDS 연결 수 > 80%
- API Gateway 스로틀
- 서브넷 IP 고갈

**런북 필수화**

모든 알람은 런북 링크 필수:

```hcl
resource "aws_cloudwatch_metric_alarm" "high_5xx" {
  alarm_name        = "crawler-high-5xx-rate"
  alarm_description = "5xx error rate is too high. Runbook: [https://docs.ryuqqq.com/runbooks/high-5xx](https://docs.ryuqqq.com/runbooks/high-5xx)"
  # ... 생략 ...
}
```

---

## 6. SLO/SLI 운영

**SLO 문서 작성**

각 서비스는 다음 SLO를 정의해야 합니다:

- 가용성: 99.9% (월 43분 다운타임 허용)
- 지연시간: p95 < 500ms
- 오류율: < 0.1%

**에러버짓 정책**

7일간 에러버짓의 20% 초과 소진 시:

- 신규 기능 배포 중단
- 안정화 스프린트 진입
- RCA(Root Cause Analysis) 수행

---

## 7. 비용 거버넌스

**필수 태그 스키마**

```hcl
locals {
  required_tags = {
    owner        = "platform-team"
    cost_center  = "engineering"
    env          = "prod"
    lifecycle    = "permanent"
    data_class   = "confidential"
    service      = "crawler"
  }
}
```

**Infracost 통합**

- PR마다 비용 영향 분석
- 10% 이상 비용 증가 시 추가 승인 필요
- 월별 비용 리포트 자동 생성

**수명주기 정책**

```hcl
# S3 수명주기
resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  bucket = aws_s3_[bucket.logs.id](http://bucket.logs.id)

  rule {
    id     = "archive-old-logs"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555  # 7년
    }
  }
}
```

---

## 8. 데이터 보호 및 DR

**RPO/RTO 티어링**

- Tier 1 (결제/인증): RPO ≤ 5분, RTO ≤ 15분
- Tier 2 (핵심 서비스): RPO ≤ 1시간, RTO ≤ 1시간
- Tier 3 (일반 서비스): RPO ≤ 24시간, RTO ≤ 4시간

**백업 전략**

```hcl
resource "aws_db_instance" "main" {
  # 자동 백업
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  
  # 스냅샷
  copy_tags_to_snapshot = true
  
  # DR을 위한 Cross-Region 복제
  replicate_source_db = var.dr_enabled ? aws_db_instance.primary.arn : null
}
```

**DR 리허설**

- 분기 1회 복구 테스트 의무화
- 테스트 결과 문서화 및 증빙 저장
- RTO/RPO 달성 여부 검증

---

## 9. 변경 관리 및 릴리즈 전략

**변경 위험도 분류**

수준 1 (저위험):

- 로그 레벨 변경
- 태그 추가/수정
- 스케일 파라미터 (task count, instance size)

수준 2 (중위험):

- 보안 그룹 규칙
- 라우팅 테이블
- ALB 리스너 규칙
- 환경 변수

수준 3 (고위험):

- DB 스키마 변경
- 데이터 파괴적 변경
- 네트워크 토폴로지 변경
- IAM 정책 변경

**배포 전략**

- 수준 2 이상: 블루/그린 또는 카나리 배포 필수
- 수준 3: 롤백 계획 + 비상 연락망 + 점검 체크리스트

**롤백 절차**

모든 고위험 변경은 롤백 계획 명시:

```markdown
## Rollback Plan
- Trigger: 5xx > 5% for 5 minutes
- Steps:
  1. Execute: `atlantis plan -d stacks/crawler/prod -var="version=1.2.3"`
  2. Execute: `atlantis apply -d stacks/crawler/prod`
- Expected Duration: 5 minutes
- Validation: Check dashboard at https://...
```

---

## 10. 데이터베이스 운영 표준

**RDS 표준 구성**

```hcl
resource "aws_db_instance" "main" {
  # Multi-AZ 필수
  multi_az = true
  
  # RDS Proxy 권장
  # (연결 풀링, 장애 조치 시간 단축)
  
  # 파라미터 그룹 표준
  parameter_group_name = "ryuqqq-postgres-14"
  
  # 읽기 리플리카 (부하 분산)
  replica_count = [var.read](http://var.read)_replica_count
  
  # 암호화
  storage_encrypted = true
  kms_key_id       = aws_kms_key.db.arn
  
  # 성능 인사이트
  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled    = true
}
```

**연결 풀링 가이드**

- 서비스당 최대 연결 수 정의
- RDS Proxy 사용 권장
- 부하 테스트로 적정 커넥션 수 검증

---

## 11. 보안 스캔 및 정책 검증

### 개요

인프라 코드 보안과 규정 준수를 위해 다중 보안 스캔 도구를 활용합니다.

### 보안 스캔 도구

#### tfsec (보안 취약점 탐지)

**목적**: Terraform 코드의 보안 취약점 식별

**주요 검증 항목**:
- 암호화 표준 (KMS at-rest/in-transit)
- 퍼블릭 접근 제어
- IAM 보안 정책
- 네트워크 보안 설정
- 로깅 및 모니터링 요구사항

**설정 파일**: `.tfsec/config.yml`

**최소 심각도**: MEDIUM (CRITICAL, HIGH, MEDIUM 보고)

**실행 방법**:
```bash
# 로컬 실행
./scripts/validators/check-tfsec.sh [terraform_directory]

# 전체 스캔
tfsec terraform/ --config-file .tfsec/config.yml
```

#### Checkov (정책 준수 검증)

**목적**: 컴플라이언스 프레임워크 및 정책 준수 검증

**지원 프레임워크**:
- CIS AWS Foundations Benchmark v1.4.0
- PCI-DSS v3.2.1
- HIPAA
- ISO/IEC 27001

**설정 파일**: `.checkov.yml`

**실행 방법**:
```bash
# 로컬 실행
./scripts/validators/check-checkov.sh [terraform_directory]

# 전체 스캔
checkov -d terraform/ --config-file .checkov.yml
```

**Skip 규칙 관리**: `docs/governance/CHECKOV_POLICY_GUIDE.md` 참고

### CI/CD 통합

#### GitHub Actions Workflow

모든 PR에서 자동으로 보안 스캔이 실행됩니다:

```yaml
- name: Run Governance Validators
  run: |
    ./scripts/validators/check-tags.sh
    ./scripts/validators/check-encryption.sh
    ./scripts/validators/check-naming.sh
    ./scripts/validators/check-tfsec.sh
    ./scripts/validators/check-checkov.sh
```

#### PR 코멘트

보안 스캔 결과는 PR 코멘트로 자동 게시:

```markdown
#### 🛡️ Security Scan (tfsec)
**Security Scan Summary:**
🚨 Critical: 0
❌ High: 0
⚠️ Medium: 2

#### 🔐 Policy Compliance (checkov)
**Policy Compliance Summary:**
✅ Passed: 15
❌ Failed: 2
⊘ Skipped: 0

**Compliance Frameworks:**
✅ CIS AWS Benchmark
⚠️ CIS AWS: 2 issues
```

### 보안 스캔 실패 시 대응 프로세스

1. **결과 파일 확인**
   ```bash
   # tfsec 결과
   cat tfsec-results.json | jq

   # checkov 결과
   cat checkov-results.json | jq
   ```

2. **이슈 상세 분석**
   - 이슈 설명 및 심각도 확인
   - 영향받는 리소스 파악
   - 수정 가이드라인 검토

3. **수정 방법 결정**
   - **코드 수정** (권장): 보안 설정을 코드로 수정
   - **Skip 규칙 추가**: 정당한 사유가 있는 경우만

4. **Skip 규칙 추가 절차**
   - 사유 문서화
   - 보안팀 또는 플랫폼팀 승인
   - 정기 검토 일정 설정

### 심각도 기준

| 심각도 | 처리 방침 | 예시 |
|--------|----------|------|
| **CRITICAL** | 즉시 수정 필수, 배포 차단 | 암호화 미적용, 퍼블릭 접근 허용 |
| **HIGH** | PR 승인 전 수정 필수 | IAM 과도한 권한, 보안 그룹 과도한 오픈 |
| **MEDIUM** | PR 승인 전 수정 권장 | 로깅 미활성화, 버저닝 미설정 |
| **LOW** | 수정 권장 (non-blocking) | 문서화 누락, 최적화 기회 |

### Pre-commit Hook 설정

로컬 커밋 전 자동 검증:

```bash
# Pre-commit 설치
pip install pre-commit

# Hook 활성화
pre-commit install

# 수동 실행
pre-commit run --all-files
```

### 관련 문서

- [Checkov Policy Guide](./CHECKOV_POLICY_GUIDE.md) - Checkov 정책 가이드 및 Skip 규칙
- [Security Scan Report Template](./SECURITY_SCAN_REPORT_TEMPLATE.md) - 보안 스캔 리포트 템플릿
- [Naming Convention](./NAMING_CONVENTION.md) - 리소스 네이밍 규칙
- [Tagging Standards](./TAGGING_STANDARDS.md) - 태그 표준

### 주의사항

**금지 사항**:
- 프로덕션 환경에서 Critical/High 이슈 Skip
- 정당한 사유 없는 Skip 규칙 추가
- 보안 스캔 결과 무시 또는 우회

**권장 사항**:
- 분기별 Skip 규칙 재검토
- 신규 규칙 업데이트 주기적 확인
- 보안 스캔 실패 패턴 분석 및 개선