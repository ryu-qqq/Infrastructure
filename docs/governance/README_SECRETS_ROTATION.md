# Secrets Rotation 문서 가이드

**작성일**: 2025-10-20  
**관리**: Platform Team

---

## 📚 문서 구성

이 디렉토리에는 AWS Secrets Manager의 자동 로테이션과 관련된 문서들이 있습니다.

### 1. [SECRETS_ROTATION_CHECKLIST.md](./SECRETS_ROTATION_CHECKLIST.md)

**대상**: DevOps 엔지니어, SRE  
**용도**: Rotation 실행 시 체크리스트 및 운영 가이드

**포함 내용**:
- ⏰ Rotation 프로세스 타임라인 분석
- ⚠️ 위험 요소 및 영향 범위
- ✅ Phase별 체크리스트 (사전/실행 중/사후)
- 🚨 긴급 롤백 절차
- 🔧 단계별 개선 권장사항

**언제 읽어야 하나?**
- Rotation 정책을 처음 도입할 때
- 프로덕션에서 rotation 실행 전
- Rotation 관련 장애 발생 시
- 정기 rotation 수행 시

### 2. [SECRETS_ROTATION_CURRENT_STATUS.md](./SECRETS_ROTATION_CURRENT_STATUS.md)

**대상**: 인프라 담당자, 아키텍트  
**용도**: 현재 인프라의 rotation 구현 상태 분석

**포함 내용**:
- 📊 현재 Terraform 설정 분석
- ✅ 구현된 기능 목록
- ⚠️ 개선 필요 항목
- 🎯 우선순위별 조치 계획
- 📋 검증 명령어 모음

**언제 읽어야 하나?**
- 프로젝트 온보딩 시
- Rotation 정책 검토 시
- 인프라 감사 전
- 개선 작업 계획 수립 시

### 3. 검증 스크립트: [scripts/validators/check-secrets-rotation.sh](../../scripts/validators/check-secrets-rotation.sh)

**대상**: 모든 인프라 팀원  
**용도**: 자동화된 rotation 상태 검증

**기능**:
- ✅ Secrets 목록 및 rotation 상태 확인
- ✅ Lambda 함수 존재 및 설정 검증
- ✅ CloudWatch 알람 확인
- ✅ 최근 rotation 로그 분석 (verbose 모드)
- ✅ 종합 결과 리포트

**사용 방법**:
```bash
# 기본 실행
./scripts/validators/check-secrets-rotation.sh

# 상세 모드
./scripts/validators/check-secrets-rotation.sh --verbose

# 다른 리전
./scripts/validators/check-secrets-rotation.sh --region us-east-1
```

---

## 🚀 Quick Start

### 신규 프로젝트 담당자

1. **현황 파악** (10분)
   ```bash
   # 1. 문서 읽기
   cat docs/governance/SECRETS_ROTATION_CURRENT_STATUS.md
   
   # 2. 자동 검증 실행
   ./scripts/validators/check-secrets-rotation.sh --verbose
   ```

2. **체크리스트 숙지** (15분)
   ```bash
   cat docs/governance/SECRETS_ROTATION_CHECKLIST.md
   ```

3. **실제 설정 확인** (5분)
   ```bash
   cd terraform/rds
   grep -A 5 "enable_secrets_rotation" variables.tf
   terraform state list | grep rotation
   ```

### Rotation 실행 전

```bash
# 1. 검증 스크립트 실행
./scripts/validators/check-secrets-rotation.sh

# 2. 체크리스트 열기
open docs/governance/SECRETS_ROTATION_CHECKLIST.md

# 3. Phase 1 (사전 점검) 항목 체크

# 4. 모니터링 대시보드 준비

# 5. Rotation 실행
aws secretsmanager rotate-secret \
  --secret-id <secret-name> \
  --region ap-northeast-2
```

### 장애 발생 시

```bash
# 1. 즉시 롤백 섹션 참조
# docs/governance/SECRETS_ROTATION_CHECKLIST.md의 "긴급 롤백 절차"

# 2. 로그 확인
aws logs tail /aws/lambda/secrets-manager-rotation --follow

# 3. 이전 버전으로 복구 (체크리스트 참조)
```

---

## 📋 문서 읽는 순서

### 케이스 1: Rotation 정책이 처음이라면

```
1️⃣ SECRETS_ROTATION_CURRENT_STATUS.md (개요 파악)
   ↓
2️⃣ check-secrets-rotation.sh 실행 (현재 상태 확인)
   ↓
3️⃣ SECRETS_ROTATION_CHECKLIST.md (운영 방법 학습)
   ↓
4️⃣ 개선 작업 수행
```

### 케이스 2: Rotation 실행이 처음이라면

```
1️⃣ SECRETS_ROTATION_CHECKLIST.md (체크리스트 숙지)
   ↓
2️⃣ check-secrets-rotation.sh 실행 (사전 검증)
   ↓
3️⃣ Phase 1: 사전 점검 수행
   ↓
4️⃣ Rotation 실행 및 모니터링
   ↓
5️⃣ Phase 3: 사후 검증
```

### 케이스 3: 장애 발생 시

```
1️⃣ SECRETS_ROTATION_CHECKLIST.md → "긴급 롤백 절차"
   ↓
2️⃣ 롤백 명령 실행
   ↓
3️⃣ check-secrets-rotation.sh 실행 (복구 확인)
   ↓
4️⃣ 사후 분석 및 개선
```

---

## 🔗 관련 리소스

### 프로젝트 내부 문서
- [Secrets Management 전략](../../claudedocs/secrets-management-strategy.md) - 전체 시크릿 관리 정책
- [KMS 전략 가이드](../../claudedocs/kms-strategy.md) - 암호화 키 관리
- [인프라 거버넌스](./infrastructure_governance.md) - 전체 거버넌스 정책

### Terraform 리소스
- `terraform/secrets/` - Secrets Manager 모듈
- `terraform/rds/secrets.tf` - RDS 시크릿 설정
- `terraform/secrets/lambda/rotation.py` - Rotation Lambda 코드

### AWS 공식 문서
- [Secrets Manager Rotation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)
- [Lambda Rotation Functions](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets-lambda-function-customizing.html)
- [RDS Password Rotation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets-rds.html)

---

## 🆘 지원 및 문의

### 긴급 상황 (프로덕션 장애)
1. **즉시**: [긴급 롤백 절차](./SECRETS_ROTATION_CHECKLIST.md#-긴급-롤백-절차) 실행
2. **Slack**: `#platform-emergency` 채널에 알림
3. **GitHub**: [긴급 이슈 생성](https://github.com/ryu-qqq/Infrastructure/issues/new?labels=critical,rotation)

### 일반 문의
- **Slack**: `#platform-team`
- **GitHub Issues**: [인프라 이슈](https://github.com/ryu-qqq/Infrastructure/issues)
- **Wiki**: [Confluence 페이지](링크)

### 개선 제안
- **PR 환영**: `docs/governance/` 문서 개선
- **이슈 등록**: 새로운 체크 항목 제안
- **Runbook 기여**: 실제 운영 경험 공유

---

## ✅ 체크리스트: 문서 이해도 자가 진단

읽고 난 후 아래 질문에 답할 수 있는지 확인하세요:

### 기본 이해
- [ ] Secrets Manager Rotation의 4단계 프로세스를 설명할 수 있는가?
- [ ] RDS 비밀번호가 언제 실제로 변경되는지 아는가?
- [ ] 애플리케이션이 새 비밀번호를 언제 알게 되는지 이해하는가?

### 운영 능력
- [ ] Rotation 실행 전에 무엇을 확인해야 하는지 아는가?
- [ ] Rotation 중 장애 발생 시 어떻게 대응하는지 아는가?
- [ ] 롤백 명령을 외부 도움 없이 실행할 수 있는가?

### 문제 해결
- [ ] 현재 인프라의 rotation 설정 상태를 확인할 수 있는가?
- [ ] Rotation 실패 원인을 CloudWatch Logs에서 찾을 수 있는가?
- [ ] 개선이 필요한 부분을 식별하고 우선순위를 정할 수 있는가?

**모두 체크했다면**: 🎉 Rotation 운영 준비 완료!  
**일부만 체크했다면**: 📚 해당 섹션 다시 읽기 권장  
**대부분 체크 안 됐다면**: 👋 팀 동료에게 페어 리뷰 요청

---

## 📅 정기 검토 일정

### 월간 (매월 첫째 주 월요일)
- [ ] `check-secrets-rotation.sh` 실행
- [ ] Rotation 실패 로그 리뷰
- [ ] CloudWatch 알람 상태 확인

### 분기별 (분기 말)
- [ ] 문서 업데이트 (신규 시크릿, 변경 사항)
- [ ] Rotation 정책 검토 (주기, 대상)
- [ ] 개선 항목 우선순위 재평가

### 연간 (1월)
- [ ] 전체 Rotation 정책 감사
- [ ] 애플리케이션 재시도 로직 검증
- [ ] Chaos Engineering 테스트 수행

---

**마지막 업데이트**: 2025-10-20  
**다음 리뷰 예정**: 2025-11-20  
**문서 버전**: 1.0
