🤖 AI 기반 인프라 자동화 플러그인 (Claude Code Integration)
🎯 목적

이 플러그인은 Claude Code와 연동되어 개발자가 직접 Terraform을 작성하지 않아도,
회사 인프라 컨벤션에 맞는 Terraform 코드를 자동으로 생성하고 배포하도록 돕습니다.

즉, "ECS 서비스 하나 추가해줘" → Terraform 코드 자동 생성 → PR → Atlantis Apply 까지
한 번의 명령(/infra) 으로 처리됩니다.

🧩 구성 개요
구성요소	설명
Claude Code Plugin (Custom)	Claude 내부에서 /infra 명령으로 Terraform 코드를 생성
Infrastructure Convention Modules	본 레포의 terraform/modules 디렉토리 기반으로 코드 생성
Atlantis Integration	Claude가 생성한 코드가 PR로 올라오면 자동으로 plan → apply 수행
Validation Hooks	생성된 코드가 CLA, 보안, 태깅, 비용 기준을 자동 검증 (tfsec, checkov, OPA, Infracost)
⚙️ 작동 흐름

명령 입력 (Claude Code 내부)

/infra "ECS 서비스와 ALB를 연결한 API 인프라를 생성해줘"


Claude Hook 실행

Claude의 user-prompt-submit.sh Hook이 “infra” 명령을 감지

내부 Cache에서 인프라 규칙(JSON)을 로드

“ECS + ALB + CloudWatch Logs” 모듈 템플릿 조합

Terraform 코드 자동 생성

terraform/services/{service-name}/ 디렉토리에 자동 생성

모듈 예시:

module "ecs_service" {
source      = "../../modules/ecs-service"
service_name = "api"
cpu          = 256
memory       = 512
}
module "alb" {
source = "../../modules/alb"
target_group = module.ecs_service.target_group
}


PR 자동 생성 및 Atlantis 연동

Claude Code → GitHub CLI 연동으로 PR 생성

Atlantis가 자동으로 terraform plan 수행

Reviewer 승인 후 apply 자동 실행

결과 리포트

Claude가 plan 결과를 요약하여 Slack 또는 Claude 콘솔에 리턴

“🚀 ECS 서비스(api)가 배포 완료되었습니다” 형태의 피드백

🧠 Claude Hook 구조
Hook 이름	역할
user-prompt-submit.sh	/infra 명령 감지 및 명령 파싱
build-infra-template.py	모듈 조합 및 Terraform 코드 생성
validate-infra.sh	생성된 코드에 대해 fmt, validate, tfsec, OPA 검증
create-pr.sh	GitHub CLI를 통해 자동 PR 생성
🔧 설치 및 설정

Claude Code 프로젝트에서 .claude/hooks 폴더 생성

다음 명령 실행:

git clone https://github.com/ryu-qqq/Infrastructure.git
cp -R Infrastructure/.claude/hooks ./your-project/.claude/hooks


Hook 권한 설정:

chmod +x .claude/hooks/*.sh


Claude Code 내부에서 Hook 등록:

/hooks


이후 다음을 등록:

UserPromptSubmit: .claude/hooks/user-prompt-submit.sh

PreToolUse: .claude/hooks/build-infra-template.py

PostToolUse: .claude/hooks/validate-infra.sh

🧩 개발자 워크플로우
단계	설명	결과
/infra "Redis 캐시 추가"	Claude가 Redis 모듈 기반 코드 생성	terraform/redis/main.tf 생성
git push	PR 자동 생성	Atlantis plan 실행
리뷰 후 머지	Apply 자동 수행	Redis 인프라 생성 완료
🚀 향후 계획
단계	목표
1단계 (현재)	Claude Code 플러그인을 통해 Terraform 코드 자동 생성
2단계	모듈별 입력값 자동 추론 (ex. VPC/Subnet 자동 참조)
3단계	인프라 상태 자동 점검 + 재구성 제안 (Self-healing)
4단계	내부 템플릿 마켓플레이스 구축 (infrastructure templates hub)
📚 참고

Claude Code Dynamic Hooks Guide

Atlantis Operations Guide

Module Standards Guide

💡 요약

이 시스템의 핵심은 “개발자가 인프라를 몰라도 회사 표준에 맞는 코드를 Claude가 대신 작성하고,
안전하게 Atlantis가 배포까지 자동으로 수행하는 하이브리드 AI 인프라 관리 환경”을 만드는 것입니다.