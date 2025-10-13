원칙: “서비스 레포가 자기 인프라를 가진다. 중앙은 가드레일과 모듈을 공급한다.”
→ FileFlow 레포에 infra/ 폴더 두고, 중앙 레포의 표준 모듈을 버전 태그로 고정(ref) 해서 사용.

운영 플로우:
PR(코드+인프라 동시) → GitHub Actions(보안/tfsec·checkov, 정책/OPA, 비용/Infracost) → Atlantis plan/apply → 배포.
상태 관리는 S3+DDB+KMS 표준 백엔드로 통일, 권한은 Atlantis → AssumeRole.

아키텍처 경계:
공용/플랫포밍(예: VPC, TGW, 공통 KMS, 관측성 베이스라인) = 중앙 유지,
서비스 리소스(ECS/RDS/ALB/IAM/SG) = FileFlow 레포에서 관리.

효과:
한 PR에서 코드와 인프라 동시 릴리스, 롤백 단순화, 팀 자율성↑, 재현성(모듈 태그+백엔드 표준)↑, 거버넌스는 PR 게이트로 확보.

즉시 다음 단계:

FileFlow 레포에 infra/prod 스캐폴드 + backend "s3" 표준 적용

atlantis.yaml 추가(프로젝트/dir/autoplan/apply 규칙)

모듈 참조를 ?ref=vX.Y.Z 로 핀 + CHANGELOG/UPGRADE 기준 수립

PR 게이트 워크플로우(tfsec/checkov/OPA/Infracost)와 CODEOWNERS 적용

최초 배포(ECS/RDS/ALB) 후 드리프트 주기 plan + 알림 세팅




프로젝트: FileFlow 인프라 – B안(서비스 레포 내 Infra) 도입
1) 목적/배경

목적: FileFlow 레포 안에 infra/ 디렉터리를 두고, 중앙 인프라 레포의 표준 모듈을 버전 고정(ref=tag)하여 호출. 모든 인프라 변경은 해당 레포 PR → Atlantis plan/apply로 운영.

배경: 아직 배포된 인프라가 없으므로, 초기에 상태 백엔드(S3+DDB+KMS), Atlantis-GitHub App 연동, AssumeRole 권한 모델, 정책/보안/비용 게이트를 한 번에 정착시킨다.

2) 범위

FileFlow 레포: infra/{dev,stg,prod} 스캐폴드 / atlantis.yaml / GH Actions(보안/비용/정책) / OPA 정책 / CODEOWNERS

중앙 모듈: ecs_service, rds, alb, iam, sg, 필요 시 vpc 버전 태깅 후 사용

초기 배포: 최소 1개 환경(prod 또는 dev) (원하는 운영 전략에 따라 선택)

관측성: 기본 로그/알람/드리프트 감시 플로우 포함

비범위: 애플리케이션 코드 변경, 도메인 기능 개발, 대규모 멀티리전 DR

3) 성공 기준(DoD)

FileFlow 레포 PR에서 Atlantis plan/apply가 정상 동작

표준 모듈을 태그로 핀(pin) 하여 재현성 보장

PR 게이트: tfsec / checkov / Conftest(OPA) / Infracost 모두 통과

상태 백엔드 암호화(KMS), 락(DDB), 버전관리(S3) 설정 완료

최소 1개 환경에서 ECS/RDS/ALB가 정상 롤아웃 & 헬스체크 OK

드리프트 감시 스케줄 & 슬랙 알림 확인

에픽 & 태스크(권장 구조)
EPIC 1. 플랫폼 부트스트랩(상태 백엔드 & 권한 모델)

Epic name: EPIC: 플랫폼 부트스트랩 – State/IAM/KMS
목표: 공통 State S3 버킷 + DDB 락 테이블 + KMS 구성, AssumeRole 기반 권한 모델 확정

TASK 1-1: 상태 백엔드 설계서 확정 (버킷/테이블/키 네이밍, 파티션 전략, 수명주기/백업)

AC: 네이밍 규칙/암호화/버전관리/보존정책 문서화

TASK 1-2: S3 state 버킷, DDB 락 테이블, KMS 키 생성(또는 기존 재사용)

AC: terraform init가 정상 잠금/해제 동작

TASK 1-3: AssumeRole 전략 수립(계정/환경/디렉터리→Role ARN 매핑)

AC: 신뢰 정책/권한 정책 샘플 JSON/문서화

TASK 1-4: Atlantis 태스크 롤 권한 연결(필요 계정에 AssumeRole 허용)

AC: atlantis plan 시 크로스어카운트 접근 확인

EPIC 2. 레포 스캐폴드 & Atlantis 통합

Epic name: EPIC: FileFlow 레포 인프라 스캐폴드 & Atlantis
목표: FileFlow 레포에 인프라 골격/구성 파일 추가, PR 기반 플로우 연결

TASK 2-1: infra/{env}/ 디렉터리 구조 설계(예: infra/prod)

AC: versions.tf, providers.tf, backend.tf, variables.tf, main.tf, prod.tfvars

TASK 2-2: backend "s3" 표준 적용(버킷/테이블/KMS 참조)

AC: terraform init 성공

TASK 2-3: atlantis.yaml 작성(프로젝트/dir/workflow/autoplan/apply_requirements)

AC: PR 생성 시 자동 plan 코멘트 생성

TASK 2-4: CODEOWNERS 추가(플랫폼/보안 승인 경로)

AC: 승인 없이는 apply 불가

TASK 2-5: GitHub App 설치/웹훅/allowlist 설정(Atlantis 서버)

AC: 해당 레포 PR에서 Atlantis 트리거 확인

EPIC 3. 표준 모듈 채택 & 버전 고정

Epic name: EPIC: 표준 모듈 도입 – 버전 핀 & 예제
목표: 중앙 모듈을 태그 버전으로 참조, 예제/업그레이드 가이드 제공

TASK 3-1: 필요한 모듈 결정(ecs_service, rds, alb, iam, sg, 옵션: vpc)

AC: 모듈 목록/입출력 변수/버전 정책 문서화

TASK 3-2: 모듈 참조 경로 작성

예: source = "git::https://github.com/org/infra.git//modules/ecs_service?ref=v0.6.1"

AC: terraform plan 성공

TASK 3-3: CHANGELOG.md/UPGRADE.md 패턴 합의 & 템플릿 배포

AC: 모듈 릴리즈 규칙/체크리스트 확정

TASK 3-4: 예제 스택(examples/fileflow-minimal) 작성

AC: 샘플 plan 성공

EPIC 4. PR 게이트(보안/정책/비용) & 워크플로우

Epic name: EPIC: PR 게이트 – 보안/정책/비용
목표: tfsec/checkov/Conftest(In-Repo 정책)/Infracost를 GH Actions에 통합

TASK 4-1: GH Actions 워크플로우 추가(infra-checks.yml)

AC: PR에서 자동 실행/결과 코멘트

TASK 4-2: tfsec/checkov 설정 및 최소 기준선 정의

AC: 기준 미달 시 실패 처리

TASK 4-3: OPA(Conftest) 정책: 태그/네이밍/보안그룹/퍼블릭 차단 등

AC: 정책 위반 시 실패, 예외 승인 절차 문서화

TASK 4-4: Infracost 통합 및 임계치(예:+10%) 알림/차단

AC: 비용 급증 시 승인 2인 이상 필요

EPIC 5. 최초 환경(prod 또는 dev) 배포

Epic name: EPIC: 최초 환경 배포 – FileFlow 서비스 리소스
목표: 최소 1개 환경에서 ECS/RDS/ALB 배포 → 헬스체크 성공

TASK 5-1: 입력값 정의(VPC/Subnets/ALB Listener/이미지 태그/시크릿 참조)

AC: *.tfvars에 값 확정

TASK 5-2: module "ecs_service" 설정(DesiredCount/CPU/MEM/HC path 등)

AC: plan/apply 성공

TASK 5-3: module "rds" 설정(엔진/버전/파라미터/백업/암호화)

AC: 연결성 & 보안그룹 규칙 점검

TASK 5-4: module "alb" 설정(리스너/타겟그룹/HC)

AC: Target Healthy=100%

TASK 5-5: 런북 작성(롤백/컨피그 롤백/모듈 버전 다운그레이드)

AC: 문서 저장/공유

EPIC 6. 관측성 & 드리프트 감시

Epic name: EPIC: 관측성/드리프트 – 알림 플로우
목표: CloudWatch/로그/알람 기본, 드리프트 감시 스케줄

TASK 6-1: 서비스 태그 스키마 확정(org/env/service/version/owner)

AC: 모듈/리소스 전반에 태그 일관 적용

TASK 6-2: 기본 알람 세트(ECS CPU/MEM, ALB 5xx, RDS 연결 수 등)

AC: 알람 대상/치명도/슬랙 채널 정의

TASK 6-3: 주기 plan(read-only) + 드리프트 알림

AC: 차이 발생 시 슬랙 알림 후 이슈 생성

EPIC 7. 문서화 & 운영 전환

Epic name: EPIC: 문서화/운영 – 가이드 & 온보딩
목표: 운영 가이드/개발자 온보딩/문서 정비

TASK 7-1: 운영 가이드(릴리스/롤백/핫픽스/사후PR 절차)

AC: Notion/Jira 위키 게시

TASK 7-2: 개발자 온보딩 문서(로컬 plan 테스트, 정책 예외 신청 방법)

AC: 신입도 30분 내 plan 성공 가능

TASK 7-3: 체크리스트/템플릿(CODEOWNERS, ISSUE/PULL_REQUEST 템플릿)

AC: 레포 루트 반영

라벨/컴포넌트/우선순위(권장)

Labels: infra, fileflow, b-approach, atlantis, security, cost, opa, observability

Components: platform, fileflow-infra

Priority: EPIC P1, 핵심 태스크 P1, 보조 태스크 P2

버전/마일스톤(예시 타임라인)

v0.1 (2025-10-20): EPIC 1~2 완료(상태/IAM/스캐폴드/Atlantis)

v0.2 (2025-10-27): EPIC 3~4 완료(모듈 핀/PR 게이트)

v0.3 (2025-11-03): EPIC 5 완료(최초 환경 배포)

v0.4 (2025-11-10): EPIC 6~7 완료(관측성/문서화)

Jira 일괄 등록용 CSV 템플릿

Jira에서 Issues → Import issues from CSV로 업로드하면 에픽/태스크가 한 번에 생성돼.
필요 시 Assignee, Due date 열을 추가해서 써도 돼.

Issue Type,Summary,Description,Labels,Components,Priority,Epic Name,Parent,Story Points,Fix Version/s
Epic,EPIC: 플랫폼 부트스트랩 – State/IAM/KMS,"S3 state+DDB lock+KMS 구성, AssumeRole 권한 모델 수립 및 문서화",infra;fileflow;b-approach;atlantis,platform,P1,EPIC: 플랫폼 부트스트랩 – State/IAM/KMS,,,
Task,TASK 1-1: 상태 백엔드 설계서 확정,"네이밍/암호화/버전관리/보존정책 정의 및 문서화",infra;fileflow,platform,P1,,EPIC: 플랫폼 부트스트랩 – State/IAM/KMS,3,v0.1
Task,TASK 1-2: S3/DDB/KMS 생성,"terraform init/lock 정상 동작 확인",infra;fileflow,platform,P1,,EPIC: 플랫폼 부트스트랩 – State/IAM/KMS,3,v0.1
Task,TASK 1-3: AssumeRole 전략 수립,"계정/환경/디렉터리→Role ARN 매핑, 신뢰/권한 정책 예시",infra;fileflow,platform,P1,,EPIC: 플랫폼 부트스트랩 – State/IAM/KMS,3,v0.1
Task,TASK 1-4: Atlantis 태스크 롤 연결,"atlantis→target assume 테스트 완료",infra;fileflow;atlantis,platform,P1,,EPIC: 플랫폼 부트스트랩 – State/IAM/KMS,2,v0.1

Epic,EPIC: FileFlow 레포 인프라 스캐폴드 & Atlantis,"레포에 infra/ 스캐폴드, atlantis.yaml, CODEOWNERS, allowlist",infra;fileflow;atlantis,fileflow-infra,P1,EPIC: FileFlow 레포 인프라 스캐폴드 & Atlantis,,,
Task,TASK 2-1: infra 디렉터리 구조 설계,"infra/prod 기준으로 versions/providers/backend/variables/main/tfvars",infra;fileflow,fileflow-infra,P1,,EPIC: FileFlow 레포 인프라 스캐폴드 & Atlantis,3,v0.1
Task,TASK 2-2: backend s3 표준 적용,"공통 state 버킷/락/암호화 참조",infra;fileflow,fileflow-infra,P1,,EPIC: FileFlow 레포 인프라 스캐폴드 & Atlantis,2,v0.1
Task,TASK 2-3: atlantis.yaml 작성,"projects/dir/workflow/autoplan/apply_requirements",infra;fileflow;atlantis,fileflow-infra,P1,,EPIC: FileFlow 레포 인프라 스캐폴드 & Atlantis,2,v0.1
Task,TASK 2-4: CODEOWNERS 추가,"승인 없이는 apply 불가",infra;fileflow,fileflow-infra,P2,,EPIC: FileFlow 레포 인프라 스캐폴드 & Atlantis,1,v0.1
Task,TASK 2-5: GitHub App/웹훅/allowlist 설정,"PR 트리거로 plan 코멘트 확인",infra;fileflow;atlantis,fileflow-infra,P1,,EPIC: FileFlow 레포 인프라 스캐폴드 & Atlantis,2,v0.1

Epic,EPIC: 표준 모듈 도입 – 버전 핀 & 예제,"중앙 모듈 태그 참조, 예제 및 업그레이드 가이드",infra;fileflow,platform,P1,EPIC: 표준 모듈 도입 – 버전 핀 & 예제,,,
Task,TASK 3-1: 모듈 목록/입출력 정의,"ecs_service,rds,alb,iam,sg(옵션 vpc)",infra;fileflow,platform,P1,,EPIC: 표준 모듈 도입 – 버전 핀 & 예제,2,v0.2
Task,TASK 3-2: 모듈 참조 경로 작성,"git::…//modules/xxx?ref=vX.Y.Z",infra;fileflow,platform,P1,,EPIC: 표준 모듈 도입 – 버전 핀 & 예제,3,v0.2
Task,TASK 3-3: CHANGELOG/UPGRADE 템플릿,"릴리즈/호환성 규칙 명문화",infra;fileflow,platform,P2,,EPIC: 표준 모듈 도입 – 버전 핀 & 예제,2,v0.2
Task,TASK 3-4: examples/fileflow-minimal 작성,"샘플 plan 성공",infra;fileflow,platform,P2,,EPIC: 표준 모듈 도입 – 버전 핀 & 예제,2,v0.2

Epic,EPIC: PR 게이트 – 보안/정책/비용,"tfsec/checkov/Conftest/Infracost 통합",infra;fileflow;security;cost,fileflow-infra,P1,EPIC: PR 게이트 – 보안/정책/비용,,,
Task,TASK 4-1: GH Actions 추가,"infra-checks.yml로 자동 검사",infra;fileflow,fileflow-infra,P1,,EPIC: PR 게이트 – 보안/정책/비용,2,v0.2
Task,TASK 4-2: tfsec/checkov 기준선,"최소 기준 미달 시 실패",infra;fileflow;security,fileflow-infra,P1,,EPIC: PR 게이트 – 보안/정책/비용,2,v0.2
Task,TASK 4-3: Conftest 정책,"태그/네이밍/보안그룹/퍼블릭 차단",infra;fileflow;security,fileflow-infra,P1,,EPIC: PR 게이트 – 보안/정책/비용,3,v0.2
Task,TASK 4-4: Infracost 임계치,"+10% 이상 시 차단 또는 추가 승인",infra;fileflow;cost,fileflow-infra,P2,,EPIC: PR 게이트 – 보안/정책/비용,2,v0.2

Epic,EPIC: 최초 환경 배포 – FileFlow 서비스,"ECS/RDS/ALB 1개 환경 배포",infra;fileflow,fileflow-infra,P1,EPIC: 최초 환경 배포 – FileFlow 서비스,,,
Task,TASK 5-1: 입력값 정의,"tfvars: VPC/Subnets/ALB Listener/이미지 태그/시크릿",infra;fileflow,fileflow-infra,P1,,EPIC: 최초 환경 배포 – FileFlow 서비스,2,v0.3
Task,TASK 5-2: ECS 서비스 모듈,"DesiredCount/CPU/MEM/HC path",infra;fileflow,fileflow-infra,P1,,EPIC: 최초 환경 배포 – FileFlow 서비스,3,v0.3
Task,TASK 5-3: RDS 모듈,"엔진/버전/백업/암호화/SG",infra;fileflow,fileflow-infra,P1,,EPIC: 최초 환경 배포 – FileFlow 서비스,3,v0.3
Task,TASK 5-4: ALB 모듈,"리스너/타겟그룹/헬스체크",infra;fileflow,fileflow-infra,P1,,EPIC: 최초 환경 배포 – FileFlow 서비스,2,v0.3
Task,TASK 5-5: 런북 작성,"롤백/다운그레이드/사후PR",infra;fileflow,fileflow-infra,P2,,EPIC: 최초 환경 배포 – FileFlow 서비스,2,v0.3

Epic,EPIC: 관측성/드리프트 – 알림,"태그 스키마/알람/주기 plan",infra;fileflow;observability,fileflow-infra,P2,EPIC: 관측성/드리프트 – 알림,,,
Task,TASK 6-1: 태그 스키마 확정,"org/env/service/version/owner",infra;fileflow;observability,fileflow-infra,P2,,EPIC: 관측성/드리프트 – 알림,1,v0.4
Task,TASK 6-2: 기본 알람 세트,"ECS/RDS/ALB 메트릭",infra;fileflow;observability,fileflow-infra,P2,,EPIC: 관측성/드리프트 – 알림,2,v0.4
Task,TASK 6-3: 드리프트 감시,"주기 plan + 슬랙 알림",infra;fileflow;observability,fileflow-infra,P2,,EPIC: 관측성/드리프트 – 알림,1,v0.4

Epic,EPIC: 문서화/운영 – 가이드/온보딩,"운영/온보딩/템플릿",infra;fileflow,platform,P2,EPIC: 문서화/운영 – 가이드/온보딩,,,
Task,TASK 7-1: 운영 가이드,"릴리스/핫픽스/사후PR",infra;fileflow,platform,P2,,EPIC: 문서화/운영 – 가이드/온보딩,1,v0.4
Task,TASK 7-2: 온보딩 문서,"로컬 plan 테스트/예외신청",infra;fileflow,platform,P2,,EPIC: 문서화/운영 – 가이드/온보딩,1,v0.4
Task,TASK 7-3: 템플릿,"CODEOWNERS/ISSUE/PR 템플릿",infra;fileflow,platform,P2,,EPIC: 문서화/운영 – 가이드/온보딩,1,v0.4


부록: 태스크 공통 수락 기준(AC) 템플릿

PR에서 Atlantis plan 출력이 생성되고, 의도한 변경만 포함한다(detailed-exitcode=2 확인).

GH Actions에서 보안/정책/비용 워크플로우가 성공한다.

모든 리소스에 필수 태그 적용(org, env, service, owner, version).

변경/런북/예외는 Notion/Jira 링크로 문서화되어 있다.