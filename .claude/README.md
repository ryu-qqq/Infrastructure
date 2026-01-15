# Infrastructure Project - Claude Configuration

이 프로젝트의 Claude Code 설정 및 커스텀 명령어 가이드입니다.

## 디렉토리 구조

```
# 프로젝트 설정
.claude/
├── README.md                    # 이 파일
├── CLAUDE.md                    # 메인 프로젝트 가이드
├── INFRASTRUCTURE_RULES.md      # 거버넌스 규칙 상세
├── settings.local.json          # 훅 설정
└── commands/                    # 커스텀 명령어
    ├── if-module.md             # /if:module
    ├── if-validate.md           # /if:validate
    ├── if-atlantis.md           # /if:atlantis
    ├── if-shared.md             # /if:shared
    ├── n8n-search.md            # /n8n:search (템플릿 검색)
    └── n8n-create.md            # /n8n:create (워크플로 생성)

# Cursor IDE 규칙
.cursor/rules/
├── terraform.mdc                # Terraform 코드 작성 규칙
├── n8n-workflows.mdc            # n8n 워크플로 작성 규칙
└── governance.mdc               # 거버넌스 정책 참조 (alwaysApply)

# 전역 에이전트 (~/.claude/agents/)
~/.claude/agents/
├── infra-terraform-architect.md # Terraform 모듈 설계 전문가
├── infra-governance-validator.md # 거버넌스 검증 전문가
└── n8n-workflow-architect.md    # n8n 워크플로 설계 전문가

# 거버넌스 정책 (governance/)
governance/
├── policies/                    # OPA 정책 (Rego)
│   ├── tagging/                 # 필수 태그 검증
│   ├── naming/                  # 네이밍 규약
│   ├── security_groups/         # 보안 그룹 규칙
│   └── public_resources/        # 공개 리소스 제한
├── configs/                     # 도구 설정
│   ├── conftest.toml            # OPA 설정
│   ├── tfsec/                   # 보안 스캔 설정
│   ├── checkov.yml              # 컴플라이언스 설정
│   └── infracost.yml            # 비용 분석 설정
└── scripts/validators/          # 검증 스크립트
```

## 사용 가능한 커맨드

### Terraform (Infrastructure) 커맨드

| 커맨드 | 설명 | 예시 |
|--------|------|------|
| `/if:module` | 모듈 생성/관리 | `/if:module aurora-pg --type storage` |
| `/if:validate` | 거버넌스 검증 | `/if:validate --all --security` |
| `/if:atlantis` | Atlantis 작업 | `/if:atlantis status` |
| `/if:shared` | 공유 리소스 관리 | `/if:shared analyze` |

### n8n 워크플로 커맨드

| 커맨드 | 설명 | 예시 |
|--------|------|------|
| `/n8n:search` | 템플릿 검색 | `/n8n:search sentry slack` |
| `/n8n:create` | 워크플로 생성 | `/n8n:create alert-handler --type webhook` |

## 전문 에이전트

복잡한 작업 시 전문 에이전트 활용 (위치: `~/.claude/agents/`):

| 에이전트 | 용도 | 주요 기능 |
|----------|------|-----------|
| `infra-terraform-architect` | Terraform 모듈 설계 | governance/ 정책 자동 적용, 모듈 구조 생성 |
| `infra-governance-validator` | 거버넌스 검증 | OPA/tfsec/checkov 분석, 수정 가이드 제공 |
| `n8n-workflow-architect` | n8n 워크플로 설계 | 커뮤니티 템플릿 검색, 모듈 통합 |

## 빠른 시작

### 새 Terraform 모듈 만들기

```bash
/if:module my-new-module --type compute --with-example
```

### 모듈 검증하기

```bash
/if:validate terraform/modules/my-new-module
```

### 새 n8n 워크플로 만들기

```bash
# 1. 먼저 템플릿 검색
/n8n:search sentry slack

# 2. 검색 결과 참고해서 생성
/n8n:create my-alert --type webhook --services slack,github
```

## 4단계 검증 레이어

| 레이어 | 시점 | 검증 도구 | 피드백 |
|--------|------|-----------|--------|
| **Pre-commit** | 커밋 전 | fmt, validate, OPA | 1-2초 |
| **Pre-push** | 푸시 전 | tags, encryption, naming | 30초 |
| **Atlantis** | PR plan | OPA + terraform plan | 30초-1분 |
| **GitHub Actions** | PR | tfsec, checkov, infracost | 1-2분 |

## 거버넌스 규칙 요약

### 🔴 CRITICAL (필수 준수)

1. **태그**: `merge(local.required_tags)` 패턴 사용
2. **암호화**: KMS 키 사용 (AES256 금지)
3. **네이밍**: 리소스 `kebab-case`, 변수 `snake_case`
4. **시크릿**: 하드코딩 금지

### 🟡 IMPORTANT (강력 권장)

5. KMS 키 자동 회전 활성화
6. `terraform fmt` 적용
7. 리소스에 주석 추가

자세한 내용: [INFRASTRUCTURE_RULES.md](./INFRASTRUCTURE_RULES.md)

## 검증 스크립트 (governance/scripts/validators/)

```bash
# 개별 검증기
./governance/scripts/validators/check-tags.sh <path>
./governance/scripts/validators/check-encryption.sh <path>
./governance/scripts/validators/check-naming.sh <path>
./governance/scripts/validators/check-tfsec.sh <path>
./governance/scripts/validators/check-checkov.sh <path>

# 단일 파일 검증
./governance/scripts/validators/validate-terraform-file.sh <file.tf>

# OPA 정책 검증
conftest test tfplan.json --config governance/configs/conftest.toml
```

## n8n 템플릿 검색

워크플로 생성 전 n8n.io 커뮤니티 템플릿 참조:

```
https://n8n.io/workflows/
```

| 기능 | 검색어 |
|------|--------|
| 에러 알림 | "sentry slack", "error notification" |
| CI/CD | "github actions", "deployment notification" |
| 모니터링 | "cloudwatch alert", "infrastructure monitoring" |
| 이슈 관리 | "jira automation", "github issues" |
| AI 분석 | "openai analysis", "chatgpt automation" |

## 문제 해결

### 커맨드가 인식되지 않을 때

1. `.claude/commands/` 디렉토리에 파일 존재 확인
2. 파일명이 `command-name.md` 형식인지 확인
3. Claude Code 재시작

### 검증 오류 발생 시

```bash
# 수동 검증 실행
./governance/scripts/validators/check-tags.sh terraform/
./governance/scripts/validators/check-encryption.sh terraform/
./governance/scripts/validators/check-naming.sh terraform/
```

## 관련 문서

- `governance/README.md` - 전체 거버넌스 시스템
- `governance/policies/README.md` - OPA 정책 상세
- `docs/guides/opa-policy-integration-guide.md` - OPA 통합 가이드
