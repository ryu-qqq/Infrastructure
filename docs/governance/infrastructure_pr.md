# PR 게이트 체크리스트 및 워크플로우

# PR 게이트 체크리스트 및 워크플로우

## ✅ PR 게이트 규칙

**모든 PR은 아래 체크가 "모두 ✅"여야 `apply` 가능**

1. **정적 분석**: tfsec/checkov 통과 ✅
2. **비용 영향**: Infracost 변화 ≤ +10% 또는 승인 첨부 ✅
3. **태그/네이밍**: 필수 태그·정규식 통과 ✅
4. **드리프트**: `plan -detailed-exitcode` 0/2, 의도치 않은 변경 없음 ✅
5. **SLO/알람/런북**: 신규/변경 서비스는 표준 세트 포함 ✅
6. **보안/네트워크 변경**: CODEOWNERS 승인 ✅
7. **변경 수준**: 2/3급이면 블루/그린(or 카나리) 계획 명시 ✅
8. **데이터 변경**: DB/스토리지 영향 & 롤백 계획 명시 ✅
9. **문서화**: README/UPGRADE/CHANGELOG 갱신 ✅
10. **비상 롤백**: 롤백 절차/허용 윈도우 정의 ✅

---

## 🔄 Atlantis 워크플로우

### 일반적인 변경 프로세스

**1단계: 브랜치 생성 및 코드 수정**

```bash
git checkout -b feature/add-crawler-rds
# Terraform 코드 수정
git commit -m "feat: Add RDS for crawler service"
git push origin feature/add-crawler-rds
```

**2단계: PR 생성**

GitHub에서 Pull Request를 생성합니다.

**3단계: 자동 검사 실행**

- tfsec 보안 스캔
- checkov 정책 검사
- Infracost 비용 분석
- 태그/네이밍 검증
- Atlantis 자동 Plan

**4단계: 리뷰 및 승인**

- 코드 리뷰어 확인
- 변경 위험도에 따른 승인 (1인/2인/보안팀)
- 모든 체크 통과 확인

**5단계: Apply**

승인된 PR에서 `atlantis apply` 코멘트를 남깁니다.

**6단계: PR 머지**

적용이 완료되면 PR을 머지하고 브랜치를 삭제합니다.

### Atlantis 명령어

```bash
atlantis plan                    # 전체 Plan
atlantis plan -d stacks/crawler  # 특정 디렉토리만 Plan
atlantis apply                   # Apply 실행
atlantis unlock                  # Lock 해제
```

---

## 🔒 Atlantis 운영 보안

**인증 및 권한**

```yaml
# atlantis.yaml
repos:
  - id: [github.com/ryu-qqq/shared-infra](http://github.com/ryu-qqq/shared-infra)
    workflow: shared-infra
    allowed_overrides: []
    allow_custom_workflows: false
    
workflows:
  shared-infra:
    plan:
      steps:
        - init
        - plan:
            extra_args: ["-detailed-exitcode"]
    apply:
      steps:
        - apply
    
    # AssumeRole로 최소 권한 적용
    aws:
      assume_role:
        role_arn: arn:aws:iam::123456789:role/atlantis-shared-infra
```

**보안 강화**

- GitHub App 서명 검증
- Webhook IP Allowlist
- TLS 1.3 강제
- 보호 브랜치에서만 apply 허용

---

## 🛠️ 모듈 버전 관리

**SemVer 적용**

```hcl
module "ecs_service" {
  source  = "[github.com/ryu-qqq/terraform-modules//ecs-service?ref=v1.2.3](http://github.com/ryu-qqq/terraform-modules//ecs-service?ref=v1.2.3)"
  
  # ... 변수들 ...
}
```

**CHANGELOG 및 UPGRADE 문서**

```markdown
# [CHANGELOG.md](http://CHANGELOG.md)

## [1.2.3] - 2025-10-15
### Added
- Health check grace period configuration

### Changed
- Default task memory from 512 to 1024

### Fixed
- ALB target group deregistration delay

## [1.2.2] - 2025-10-10
...
```

```markdown
# [UPGRADE.md](http://UPGRADE.md)

## Upgrading from v1.1.x to v1.2.x

### Breaking Changes
- `container_port` is now required
- `enable_execute_command` defaults to `false`

### Migration Steps
1. Add `container_port = 8080` to your module call
2. Run `terraform plan` to verify changes
3. Review changes carefully before applying
```

**파괴적 변경**

- 메이저 버전 업그레이드
- 마이그레이션 도구/가이드 제공
- 샌드박스에서 사전 검증

---

## 📢 비상 절차

### 긴급 변경이 필요한 경우

**절차**

1. 플랫폼팀에 긴급 승인 요청
2. 로컴에서 Terraform 직접 실행
3. 변경 후 24시간 내 PR 생성 (실제 적용된 내용 반영)
4. 사후 리뷰 및 개선 사항 도출

**비상 연락망**

- 플랫폼팀 리드: [Slack #infra-emergency]
- 보안팀: [Slack #security-alerts]
- 온콜 담당자: [PagerDuty Rotation]

### Atlantis 서버 다운 시

Atlantis는 stateless하며, Terraform 상태는 S3에 안전하게 저장됩니다.

**대응 방법**

1. 로컴에서 Terraform 직접 실행 가능
2. Atlantis 서버 복구 시도
3. 변경 후 반드시 PR 생성하여 이력 남김

---

## 📊 품질 보증

### 자동화된 검사

**보안 스캔**

```yaml
# .github/workflows/terraform-check.yml
- name: Run tfsec
  uses: aquasecurity/tfsec-action@v1.0.0
  with:
    soft_fail: false  # 실패 시 PR 차단

- name: Run checkov
  uses: bridgecrewio/checkov-action@master
  with:
    framework: terraform
    soft_fail: false
```

**비용 분석**

```yaml
- name: Run Infracost
  uses: infracost/infracost-action@v2
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}
    show-skipped: true
```

**태그 검증**

```hcl
variable "cluster_name" {
  type = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens."
  }
}
```

### 코드 리뷰 포인트

**보안 검토**

- 보안 그룹 규칙이 최소 권한 원칙을 따르는가?
- 민감한 정보가 코드에 하드코딩되지 않았는가?
- KMS 키가 적절히 사용되는가?

**비용 검토**

- 리소스 태그가 올바르게 설정되었는가?
- 비용에 영향을 미치는 변경인가?
- 수명주기 정책이 적용되었는가?

**영향도 분석**

- 다른 프로젝트에 영향을 주는 변경인가?
- 다운타임이 발생하는가?
- 롤백 계획이 충분한가?

**문서화 검토**

- README가 업데이트되었는가?
- CHANGELOG에 변경 사항이 기록되었는가?
- 파괴적 변경의 경우 UPGRADE 문서가 있는가?