# AWS Console 클릭 대신 PR로 끝내는 루틴 – Terraform (1)

## 🚨 문제: AWS 콘솔 클릭의 악몽

당신은 새벽 2시, 급하게 보안 그룹 규칙을 하나 추가해야 하는 상황입니다.

1. AWS 콘솔에 로그인
2. VPC 서비스 찾기
3. 보안 그룹 메뉴 클릭
4. 수많은 보안 그룹 중 올바른 것 찾기
5. 인바운드 규칙 편집 버튼 클릭
6. 규칙 추가
7. 저장

**그런데 문제가 있습니다:**
- 누가 언제 왜 이 변경을 했는지 알 수 없습니다
- 실수로 잘못된 규칙을 추가했는지 확인할 방법이 없습니다
- 다른 팀원이 똑같은 작업을 중복으로 할 수 있습니다
- 변경사항을 되돌리기 어렵습니다
- 변경 전에 리뷰 받을 방법이 없습니다

## 📊 Before vs After

| 구분 | Console 클릭 | PR 기반 Terraform |
|------|-------------|-------------------|
| **변경 추적** | CloudTrail 로그만 존재 (검색 어려움) | Git 히스토리에 모든 변경사항 기록 |
| **코드 리뷰** | 불가능 | PR을 통한 팀원 리뷰 필수 |
| **롤백** | 수동으로 다시 클릭해서 되돌려야 함 | `git revert` 한 번으로 즉시 롤백 |
| **변경 검증** | 변경 후에나 문제 발견 | PR에서 자동 검증 (보안, 비용, 정책) |
| **문서화** | 별도로 위키/노션에 작성해야 함 | 코드 자체가 문서 |
| **협업** | 채팅/이메일로 "OO 바꿨어요" | PR에서 명확한 컨텍스트와 리뷰 |
| **재사용** | 매번 다시 클릭 | 모듈로 재사용 가능 |
| **비용 관리** | 변경 후 청구서 보고 놀람 | PR에서 예상 비용 증가 미리 확인 |

## 🎯 해결: Infrastructure as Code

**핵심 아이디어:** 인프라를 코드로 관리하면, 일반 코드처럼 Git + PR 워크플로우를 사용할 수 있습니다.

### 실제 예시: 보안 그룹 규칙 추가

**Before (Console):**
```
1. AWS 콘솔 로그인
2. VPC → Security Groups
3. "prod-api-server-sg" 찾기
4. Inbound rules 편집
5. Add rule: Type=HTTPS, Source=10.0.0.0/16
6. Save
```

**After (Terraform):**
```hcl
# terraform/network/security-groups.tf
resource "aws_security_group_rule" "api_server_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.api_server.id

  description = "Allow HTTPS from private subnet for ALB health checks"
}
```

**PR 프로세스:**
```
1. 브랜치 생성: feature/add-api-https-rule
2. 코드 작성 (위 HCL 코드)
3. git commit -m "feat: Add HTTPS rule for ALB health checks"
4. git push & PR 생성
5. 자동 검증 시작:
   ✅ Terraform plan 성공
   ✅ 보안 스캔 통과 (tfsec, checkov)
   ✅ 비용 영향: +$0/월
   ✅ 정책 검증 통과
6. 팀원 리뷰 & 승인
7. Merge → 자동 배포
```

## 🔄 실제 워크플로우

```
개발자                     GitHub                      AWS
  │                          │                          │
  ├─1. 코드 작성              │                          │
  │                          │                          │
  ├─2. git push ────────────>│                          │
  │                          │                          │
  │                          ├─3. PR 생성               │
  │                          │                          │
  │                          ├─4. 자동 검증 시작         │
  │                          │   ├─ Terraform plan     │
  │                          │   ├─ 보안 스캔          │
  │                          │   ├─ 비용 분석          │
  │                          │   └─ 정책 검증          │
  │                          │                          │
  │<─────────────────────────┤─5. PR 코멘트 (결과)      │
  │  "✅ 모든 검증 통과"       │                          │
  │  "예상 비용: +$0/월"      │                          │
  │                          │                          │
  ├─6. 팀원 리뷰 요청         │                          │
  │<───────────────────────> │                          │
  │                          │                          │
  ├─7. Merge ──────────────> │                          │
  │                          │                          │
  │                          ├─8. terraform apply ────>│
  │                          │                          │
  │                          │                  9. 인프라 변경
  │                          │                          │
  │<─────────────────────────┤────────────────────────┤
  │  "✅ 배포 완료"            │                          │
```

## 💡 핵심 이점

### 1. **변경 이력 추적**
```bash
# 누가 언제 왜 이 보안 그룹을 변경했는지 즉시 확인
git log terraform/network/security-groups.tf

# 특정 리소스의 변경 이력
git log -p -- terraform/network/security-groups.tf

# 3개월 전 상태 확인
git show HEAD@{3.months.ago}:terraform/network/security-groups.tf
```

### 2. **자동 검증**
PR을 열면 자동으로 다음 검증이 실행됩니다:

```yaml
검증 항목:
  ✅ Terraform fmt/validate (문법 검증)
  ✅ tfsec (보안 스캔 - 400+ AWS 보안 규칙)
  ✅ checkov (정책 준수 - CIS, PCI-DSS)
  ✅ Infracost (비용 영향 분석)
  ✅ OPA (조직 정책 검증)

차단 조건:
  ❌ 보안 Critical/High 이슈
  ❌ 비용 30% 이상 증가
  ❌ 필수 태그 누락
  ❌ 암호화 누락
```

### 3. **팀 협업**
```markdown
# PR 예시
## 변경 내용
- API 서버용 HTTPS 인바운드 규칙 추가
- ALB 헬스체크를 위해 프라이빗 서브넷에서 접근 허용

## 변경 이유
- ALB가 API 서버 헬스체크를 못해서 인스턴스가 unhealthy 상태
- 현재는 80 포트만 열려있어서 HTTPS 헬스체크 실패

## 테스트 계획
1. Terraform plan 확인
2. Dev 환경에서 먼저 적용
3. 헬스체크 정상 동작 확인 후 Prod 적용

## 체크리스트
- [x] 보안 그룹 규칙 최소 권한 원칙 준수
- [x] Description 명확하게 작성
- [x] 개발/스테이징 환경에서 테스트 완료
```

### 4. **재사용 가능한 모듈**
```hcl
# 같은 패턴을 여러 곳에서 재사용
module "api_server_sg" {
  source = "../../modules/security-group"

  name        = "api-server"
  vpc_id      = module.vpc.vpc_id
  environment = "prod"

  ingress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "HTTPS from ALB"
    }
  ]

  tags = local.required_tags
}

# 다른 서비스에서도 동일한 모듈 재사용
module "worker_server_sg" {
  source = "../../modules/security-group"
  # ... 다른 서비스도 같은 패턴으로
}
```

## 🎓 실제 사례: 보안 그룹 변경

### 문제 상황
새로운 마이크로서비스(Payment API)를 배포했는데, 기존 Order API에서 접근이 안 됩니다.

### Console 방식 (비권장)
1. AWS 콘솔에서 Payment API 보안 그룹 찾기
2. 인바운드 규칙에 Order API 보안 그룹 추가
3. 담당자에게 슬랙으로 "보안 그룹 열었어요" 메시지

**문제점:**
- 어떤 포트를 열었는지 명확하지 않음
- 왜 이 변경이 필요한지 컨텍스트 없음
- 나중에 이 규칙이 왜 있는지 아무도 모름

### Terraform + PR 방식 (권장)
```hcl
# terraform/services/payment-api/security-groups.tf
resource "aws_security_group_rule" "from_order_api" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.order_api.id
  security_group_id        = aws_security_group.payment_api.id

  description = "Allow Order API to call Payment API for payment processing"
}
```

**PR 설명:**
```markdown
## 변경 내용
Payment API 보안 그룹에 Order API 접근 규칙 추가

## 배경
- Order 서비스에서 결제 처리를 위해 Payment API 호출 필요
- 현재 보안 그룹 규칙이 없어서 connection timeout 발생

## 기술 스펙
- Protocol: TCP
- Port: 8080 (Payment API 서버 포트)
- Source: Order API 보안 그룹 (sg-xxxxx)

## 보안 검토
- ✅ 최소 권한 원칙 준수 (특정 SG, 특정 포트만 허용)
- ✅ Description 명확하게 작성
- ✅ 불필요한 0.0.0.0/0 노출 없음

## 테스트 결과
Dev 환경에서 테스트 완료:
- Order API → Payment API 호출 성공
- 헬스체크 정상
- 로그에 connection error 없음
```

**PR 코멘트 (자동 생성):**
```
🔍 Terraform Plan 결과:
  + aws_security_group_rule.from_order_api

✅ 보안 스캔 통과:
  - tfsec: 0 issues
  - checkov: 0 issues

💰 비용 영향:
  - 보안 그룹 규칙 추가: $0/월

📋 정책 검증:
  ✅ 필수 태그 존재
  ✅ Description 작성됨
  ✅ 특정 CIDR/SG 지정 (0.0.0.0/0 아님)
```

## 🚀 다음 단계

이제 인프라를 코드로 관리하는 이유와 장점을 알았습니다. 다음 글에서는:

1. **Atlantis 도입** - PR에 코멘트만 남기면 자동으로 Terraform 실행
2. **자동 검증 파이프라인** - 보안, 비용, 정책을 자동으로 검증
3. **프로덕션 운영 전략** - 안전한 배포와 롤백

## 📚 참고 자료

- [Terraform 공식 문서](https://www.terraform.io/docs)
- [AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

---

**다음 글:** [PR에서 인프라 관리하기 - Atlantis (2편)](./02-atlantis-pr-automation.md)
