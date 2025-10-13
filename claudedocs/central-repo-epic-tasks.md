# 중앙 Infrastructure 레포 Epic & Task 정의

## 📋 프로젝트 목표

**핵심 원칙**: "서비스 레포가 자기 인프라를 가진다. 중앙은 가드레일과 모듈을 공급한다."

### 중앙 레포의 3가지 책임
1. **플랫폼 인프라**: 모든 서비스가 공통으로 사용할 기반 (VPC, 모니터링, 로깅)
2. **표준 모듈**: 서비스 레포에서 버전 고정(ref=tag)하여 사용할 재사용 가능한 모듈
3. **가드레일**: 서비스 레포 PR을 검증하는 자동화 체계 (Atlantis, 보안/정책/비용)

---

## 🎯 Epic 구조 (총 6개)

### EPIC 1: Atlantis 플랫폼 구축
**목적**: 각 서비스 레포의 PR 기반 Terraform 자동화 기반 마련
**우선순위**: P1 (최우선)
**레이블**: `infra`, `atlantis`, `automation`, `platform`

#### TASK 1-1: Terraform State 백엔드 구축
**목표**: 모든 서비스가 사용할 공통 State 백엔드 준비

**작업 내용**:
- S3 버킷 생성
  - 버킷명: `{org}-terraform-state-{account-id}`
  - 버전 관리 활성화
  - 서버 측 암호화 (KMS)
  - 수명주기 정책 (오래된 버전 정리)
- DynamoDB Lock 테이블 생성
  - 테이블명: `terraform-state-lock`
  - Primary Key: `LockID` (String)
- KMS 키 생성 및 권한 설정
  - 키 별칭: `terraform-state-key`
  - Atlantis 역할에 암호화/복호화 권한 부여
- 백엔드 설정 문서화
  - 서비스 레포에서 사용할 backend.tf 템플릿

**완료 기준**:
- terraform init 성공
- State lock/unlock 정상 작동
- 문서화 완료

**스토리 포인트**: 3

---

#### TASK 1-2: IAM AssumeRole 권한 구조 설계
**목표**: Atlantis가 각 계정/환경의 리소스를 관리할 수 있는 권한 체계 구축

**작업 내용**:
- Atlantis ECS Task Role 생성
  - 역할명: `atlantis-task-role`
  - sts:AssumeRole 권한 부여
- 각 계정별 Target Role 생성
  - dev: `atlantis-target-dev`
  - stg: `atlantis-target-stg`
  - prod: `atlantis-target-prod`
- Trust Policy 설정
  - Target Role이 Atlantis Task Role을 신뢰하도록 설정
- 권한 정책 정의
  - Terraform 실행에 필요한 최소 권한 (ECS, RDS, ALB, IAM, VPC 등)
  - 문서화 (각 서비스별 추가 권한 요청 프로세스)

**완료 기준**:
- Atlantis에서 모든 환경 접근 가능
- 크로스 계정 AssumeRole 테스트 성공
- 권한 정책 문서화 완료

**스토리 포인트**: 5

---

#### TASK 1-3: Atlantis 서버 ECS 배포
**목표**: Atlantis 서버를 ECS에 안정적으로 배포

**작업 내용**:
- ECS Cluster 생성
  - 클러스터명: `infrastructure-cluster`
  - Fargate 사용
- Atlantis Task Definition 작성
  - 이미지: `ghcr.io/runatlantis/atlantis:latest`
  - CPU: 512, Memory: 1024
  - 환경 변수: `ATLANTIS_GH_APP_ID`, `ATLANTIS_REPO_ALLOWLIST`
  - 시크릿: GitHub App Private Key (Secrets Manager 참조)
- ECS Service 생성
  - DesiredCount: 1 (prod는 2)
  - ALB 연동 (Target Group)
  - Health Check: `/healthz`
- CloudWatch Logs 설정
  - Log Group: `/ecs/atlantis`
  - Retention: 30 days

**완료 기준**:
- ECS Service 정상 실행
- ALB Health Check 통과
- 로그 수집 확인

**스토리 포인트**: 5

---

#### TASK 1-4: GitHub App 및 Webhook 연동
**목표**: GitHub PR과 Atlantis를 연동하여 자동화 트리거

**작업 내용**:
- GitHub App 생성
  - App 이름: `Atlantis-{Org}`
  - 권한: Repository (Contents: Read, Pull Requests: Read & Write, Webhooks: Read)
- Webhook URL 설정
  - URL: `https://{atlantis-alb-dns}/events`
  - Secret: 랜덤 생성 후 Secrets Manager 저장
- App Private Key 저장
  - Secrets Manager: `/atlantis/github-app-key`
- 연동 테스트
  - 더미 레포 생성
  - PR 생성 → Atlantis plan 자동 실행 확인

**완료 기준**:
- GitHub App 정상 작동
- Webhook 이벤트 수신 확인
- Atlantis plan 코멘트 생성 확인

**스토리 포인트**: 3

---

#### TASK 1-5: 멀티 레포지토리 allowlist 설정
**목표**: FileFlow, CrawlingHub, AuthHub 레포를 Atlantis에 등록

**작업 내용**:
- `repos.yaml` 파일 작성
  ```yaml
  repos:
  - id: github.com/org/fileflow
    allowed_overrides: [workflow]
    allow_custom_workflows: true
  - id: github.com/org/crawlinghub
    allowed_overrides: [workflow]
    allow_custom_workflows: true
  - id: github.com/org/authhub
    allowed_overrides: [workflow]
    allow_custom_workflows: true
  ```
- Atlantis 환경변수 업데이트
  - `ATLANTIS_REPO_CONFIG` 또는 ConfigMap 사용
- Atlantis 재배포
  - ECS Service Update
- 각 레포 검증
  - 각 레포에 테스트 PR 생성
  - Atlantis plan 정상 실행 확인

**완료 기준**:
- 3개 레포 모두 Atlantis 연동 완료
- PR 자동 plan 실행 확인
- Apply 권한 테스트 완료

**스토리 포인트**: 2

---

#### TASK 1-6: Atlantis 운영 문서 작성
**목표**: Atlantis 운영 및 트러블슈팅 가이드 작성

**작업 내용**:
- 레포 추가/제거 프로세스
  - repos.yaml 수정 방법
  - 재배포 절차
- Atlantis 업그레이드 절차
  - 이미지 버전 업데이트
  - 설정 변경 사항 적용
- 트러블슈팅 가이드
  - 일반적인 에러 및 해결 방법
  - 로그 분석 방법
  - Lock 해제 방법
- 백업 및 복구
  - State 백업 전략
  - 재해 복구 절차

**완료 기준**:
- 운영 문서 작성 완료
- 팀 리뷰 및 승인
- Notion/Wiki 게시

**스토리 포인트**: 2

---

### EPIC 2: 공통 플랫폼 인프라
**목적**: 모든 서비스가 공통으로 사용할 기반 인프라 구축
**우선순위**: P1
**레이블**: `infra`, `platform`, `networking`, `security`

#### TASK 2-1: VPC 및 네트워크 설계
**목표**: 모든 서비스가 사용할 VPC 및 서브넷 구성

**작업 내용**:
- VPC CIDR 설계
  - dev: 10.0.0.0/16
  - stg: 10.1.0.0/16
  - prod: 10.2.0.0/16
- Subnet 구성
  - Public Subnet (ALB용): 각 AZ별 /24
  - Private Subnet (ECS, RDS용): 각 AZ별 /20
  - Database Subnet: 각 AZ별 /24
- NAT Gateway
  - 각 AZ별 NAT Gateway (고가용성)
  - prod는 AZ당 1개, dev/stg는 공유 가능
- Internet Gateway
- Route Table 설정
  - Public: IGW 연결
  - Private: NAT Gateway 연결
  - Database: NAT Gateway 연결

**완료 기준**:
- VPC 생성 완료
- 서브넷 간 통신 테스트 성공
- NAT Gateway 외부 통신 확인
- 네트워크 다이어그램 작성

**스토리 포인트**: 5

---

#### TASK 2-2: Transit Gateway 구성 (선택)
**목표**: 멀티 계정/VPC 간 통신 구성 (필요시)

**작업 내용**:
- Transit Gateway 생성 여부 결정
  - 단일 계정인 경우: Skip
  - 멀티 계정인 경우: 진행
- TGW 생성
- VPC Attachment
  - 각 계정의 VPC를 TGW에 연결
- Route Table 설정
  - 계정 간 트래픽 라우팅
- 보안 그룹 규칙
  - 필요한 트래픽만 허용

**완료 기준**:
- TGW 생성 완료 (또는 Skip 결정)
- VPC 간 통신 테스트 성공
- 문서화 완료

**스토리 포인트**: 3 (Skip 시 0)

---

#### TASK 2-3: KMS 키 전략 수립
**목표**: 용도별 KMS 키 생성 및 관리 체계 구축

**작업 내용**:
- 용도별 KMS 키 생성
  - `terraform-state-key`: State 파일 암호화
  - `rds-encryption-key`: RDS 암호화
  - `ecs-encryption-key`: ECS 태스크 볼륨 암호화
  - `secrets-encryption-key`: Secrets Manager 암호화
- 키 정책 설정
  - 서비스별 암호화/복호화 권한
  - 관리자 키 관리 권한
- 키 로테이션 정책
  - 자동 로테이션 활성화 (1년 주기)
- 사용 가이드
  - 각 서비스에서 KMS 키 사용 방법
  - 새 키 추가 프로세스

**완료 기준**:
- 4개 KMS 키 생성 완료
- 키 정책 적용 완료
- 사용 가이드 문서화

**스토리 포인트**: 3

---

#### TASK 2-4: AWS 계정 분리 전략 수립
**목표**: 계정 구조 및 권한 체계 설계

**작업 내용**:
- 계정 구조 결정
  - 옵션 A: 단일 계정 (환경별 VPC 분리)
  - 옵션 B: 멀티 계정 (Organizations 사용)
- Organizations 설정 (멀티 계정 선택 시)
  - Management Account
  - dev, stg, prod 계정 생성
  - OU (Organizational Unit) 구조
- 계정 간 IAM 권한
  - Cross-Account AssumeRole
  - Service Control Policies (SCP)
- 비용 할당 태그 전략
  - CostCenter, Environment, Team 태그
  - Cost Explorer 설정

**완료 기준**:
- 계정 구조 결정 및 문서화
- 필요시 계정 생성 완료
- 권한 체계 설정 완료

**스토리 포인트**: 3 (단일 계정 시 1)

---

#### TASK 2-5: CloudTrail 중앙 수집
**목표**: 모든 계정의 API 호출 로그를 중앙 집계

**작업 내용**:
- 중앙 CloudTrail 버킷 생성
  - 버킷명: `{org}-cloudtrail-logs`
  - 버전 관리 및 암호화
  - 수명주기 정책 (90일 보관)
- CloudTrail 활성화
  - 모든 계정에서 로그를 중앙 버킷으로 전송
  - 관리 이벤트 및 데이터 이벤트 설정
- Athena 쿼리 설정
  - CloudTrail 로그 테이블 생성
  - 일반적인 쿼리 템플릿 작성
- 보안 이벤트 알림
  - EventBridge Rule 생성
  - 특정 이벤트 발생 시 SNS 알림

**완료 기준**:
- CloudTrail 정상 작동
- Athena 쿼리 성공
- 보안 이벤트 알림 테스트 완료

**스토리 포인트**: 3

---

#### TASK 2-6: 필수 태그 및 네이밍 규약
**목표**: 일관된 태그 및 네이밍 규칙 정의 및 강제

**작업 내용**:
- 태그 스키마 정의
  - 필수 태그:
    - `Environment`: dev, stg, prod
    - `Service`: fileflow, crawlinghub, authhub
    - `Team`: 담당 팀명
    - `Owner`: 담당자 이메일
    - `CostCenter`: 비용 센터 코드
  - 선택 태그:
    - `Version`: 애플리케이션 버전
    - `ManagedBy`: terraform
- 리소스 네이밍 규칙
  - 형식: `{env}-{service}-{resource-type}`
  - 예: `prod-fileflow-ecs`, `dev-crawlinghub-rds`
- OPA 정책 작성
  - 필수 태그 검증
  - 네이밍 규칙 검증
- 문서화
  - 태그 가이드
  - 네이밍 예제

**완료 기준**:
- 태그/네이밍 규약 문서화
- OPA 정책 작성 완료
- 예제 리소스 생성 및 검증

**스토리 포인트**: 2

---

#### TASK 2-7: Secrets 관리 인프라
**목표**: AWS Secrets Manager 구조 및 사용 가이드

**작업 내용**:
- Secrets Manager 구조 설계
  - 네이밍 규칙: `/{env}/{service}/{key}`
  - 예: `/prod/fileflow/db-password`
- 시크릿 생성 프로세스
  - Terraform으로 생성 vs 수동 생성
  - 초기 시크릿 값 설정 방법
- 로테이션 정책
  - 자동 로테이션 설정 (RDS 비밀번호)
  - 로테이션 주기 (30일, 90일)
- 서비스 레포 접근 가이드
  - IAM 권한 설정
  - ECS 태스크에서 시크릿 참조 방법
  - 애플리케이션 코드에서 시크릿 로드

**완료 기준**:
- Secrets Manager 구조 문서화
- 예제 시크릿 생성 및 검증
- 사용 가이드 작성

**스토리 포인트**: 3

---

### EPIC 3: 중앙 관측성 시스템
**목적**: 로깅, 모니터링, 알림 통합 시스템 구축
**우선순위**: P1
**레이블**: `infra`, `observability`, `monitoring`, `logging`

#### TASK 3-1: 중앙 로깅 시스템 구축
**목표**: 모든 서비스의 로그를 중앙 집계 및 분석

**작업 내용**:
- CloudWatch Logs 집계 구조
  - Log Group 생성: `/aws/{service}/{env}`
  - 예: `/aws/ecs/fileflow/prod`
- Log Group 네이밍 규칙
  - 일관된 네이밍으로 필터링 용이
- Log Retention 정책
  - dev: 7일
  - stg: 30일
  - prod: 90일
- CloudWatch Logs Insights 쿼리 템플릿
  - 에러 로그 필터링
  - 성능 분석 쿼리
  - 트래픽 패턴 분석
- 로그 내보내기 (선택)
  - S3 버킷으로 아카이빙
  - Athena 쿼리 지원

**완료 기준**:
- Log Group 생성 완료
- Retention 정책 적용
- Insights 쿼리 템플릿 작성

**스토리 포인트**: 3

---

#### TASK 3-2: 모니터링 시스템 선택 및 구축
**목표**: 메트릭 수집 및 시각화 시스템 구축

**작업 내용**:
- 모니터링 시스템 선택
  - 옵션 A: CloudWatch Dashboards (간단, AWS 네이티브)
  - 옵션 B: Grafana + Prometheus (고급, 오픈소스)
- 선택한 시스템 구축
  - 옵션 A: CloudWatch Dashboard 생성
  - 옵션 B: Grafana/Prometheus ECS 배포
- 메트릭 수집 설정
  - ECS 메트릭 (CPU, Memory, TaskCount)
  - RDS 메트릭 (Connections, CPU, Storage)
  - ALB 메트릭 (RequestCount, TargetResponseTime, 5xx)
- 대시보드 템플릿 생성
  - 서비스별 대시보드
  - 인프라 전체 대시보드

**완료 기준**:
- 모니터링 시스템 구축 완료
- 메트릭 수집 확인
- 대시보드 템플릿 생성

**스토리 포인트**: 5 (CloudWatch) / 8 (Grafana)

---

#### TASK 3-3: 알림 체계 구축
**목표**: 장애 및 이벤트 알림 시스템

**작업 내용**:
- SNS Topic 생성
  - `infrastructure-critical`: 즉시 대응 필요
  - `infrastructure-warning`: 모니터링 필요
  - `infrastructure-info`: 정보성 알림
- Slack Webhook 연동
  - Lambda 함수로 SNS → Slack 포워딩
  - 알림 형식 템플릿
- 알림 룰 정의
  - CloudWatch Alarms → SNS
  - 알람 임계치 및 조건
- Runbook 링크
  - 각 알림에 대응 절차 링크 포함
  - Notion/Wiki 문서 연결

**완료 기준**:
- SNS Topic 생성 완료
- Slack 알림 수신 확인
- 알림 룰 설정 완료

**스토리 포인트**: 3

---

#### TASK 3-4: 기본 알람 세트 정의
**목표**: 공통 알람 템플릿 및 임계치 가이드

**작업 내용**:
- ECS 알람
  - CPU > 80% (5분 평균)
  - Memory > 80% (5분 평균)
  - TaskCount = 0 (1분 평균)
- RDS 알람
  - CPU > 80% (10분 평균)
  - Connections > 90% (5분 평균)
  - FreeStorageSpace < 20% (5분 평균)
- ALB 알람
  - 5xx > 5% (5분 평균)
  - TargetHealth < 100% (3분 평균)
  - ResponseTime > 1초 (5분 평균)
- 알람 임계치 가이드
  - 서비스별 조정 가능한 항목
  - 임계치 변경 프로세스

**완료 기준**:
- 알람 템플릿 작성
- 가이드 문서화
- 예제 알람 생성 및 테스트

**스토리 포인트**: 3

---

#### TASK 3-5: 드리프트 감지 자동화
**목표**: Terraform 드리프트 자동 감지 및 알림

**작업 내용**:
- EventBridge Rule 생성
  - 스케줄: 매일 09:00 UTC
  - 대상: Lambda 함수
- Lambda 함수 개발
  - Atlantis API 호출 또는 직접 terraform plan 실행
  - 드리프트 발견 시 차이점 요약
- Slack 알림 전송
  - 드리프트 요약 및 영향받는 리소스
  - PR 링크 (드리프트 해결용)
- GitHub Issues 자동 생성
  - 드리프트 내용 포함
  - 담당자 할당
- 드리프트 해결 프로세스 문서화
  - Import vs 재적용 판단 기준
  - 해결 절차

**완료 기준**:
- 스케줄 정상 작동
- 드리프트 알림 수신 확인
- 이슈 자동 생성 확인

**스토리 포인트**: 5

---

### EPIC 4: 재사용 가능한 표준 모듈
**목적**: 서비스 레포에서 사용할 검증된 Terraform 모듈 제공
**우선순위**: P1
**레이블**: `infra`, `modules`, `terraform`, `reusable`

#### TASK 4-1: 모듈 디렉터리 구조 설계
**목표**: 일관된 모듈 구조 및 버전 관리 체계

**작업 내용**:
- `modules/` 폴더 구조
  ```
  modules/
  ├── ecs_service/
  │   ├── main.tf
  │   ├── variables.tf
  │   ├── outputs.tf
  │   ├── README.md
  │   └── examples/
  ├── rds/
  ├── alb/
  └── ...
  ```
- README.md 템플릿
  - 모듈 설명
  - 필수/선택 변수
  - 출력값
  - 사용 예제
- 버전 관리 전략
  - Semantic Versioning (v1.0.0)
  - Breaking changes → Major 버전 증가
  - 새 기능 → Minor 버전 증가
  - 버그 수정 → Patch 버전 증가
- CHANGELOG.md 작성 규칙
  - 각 버전별 변경사항 기록
  - 업그레이드 가이드 링크

**완료 기준**:
- 폴더 구조 생성
- README 템플릿 작성
- 버전 관리 가이드 문서화

**스토리 포인트**: 2

---

#### TASK 4-2: ECS Service 모듈 개발
**목표**: ECS Fargate Service 생성 모듈

**작업 내용**:
- Task Definition
  - 입력: 이미지, CPU, 메모리, 환경변수, 시크릿
  - 컨테이너 정의 (로그, 포트 매핑)
  - Task Role, Execution Role
- ECS Service
  - 입력: DesiredCount, VPC, Subnets, Security Group
  - ALB Target Group 연동
  - Service Discovery (선택)
- AutoScaling (선택)
  - Target Tracking (CPU/Memory 기준)
  - Min/Max 설정
- Health Check
  - ALB Health Check 경로 설정
  - Grace Period
- 입출력 변수 정의
  - 입력: service_name, environment, image, cpu, memory, port 등
  - 출력: service_id, task_definition_arn, security_group_id 등

**완료 기준**:
- 모듈 코드 작성 완료
- terraform plan 성공
- README 및 예제 작성

**스토리 포인트**: 5

---

#### TASK 4-3: RDS 모듈 개발
**목표**: RDS 인스턴스 생성 모듈

**작업 내용**:
- DB Instance
  - 입력: 엔진(PostgreSQL/MySQL), 버전, 인스턴스 타입
  - 스토리지 (크기, 타입, 자동 증가)
  - Multi-AZ, Read Replica 옵션
- 백업 설정
  - 백업 주기, 보관 기간
  - 백업 윈도우 시간
- 암호화
  - KMS 키 사용
  - Storage 암호화
- Parameter Group
  - 엔진별 최적화된 기본값
  - 커스터마이징 가능
- Security Group
  - 입력: 허용할 소스 (ECS Security Group)
  - DB 포트만 개방
- 입출력 변수
  - 입력: db_name, engine, instance_class, storage, username 등
  - 출력: endpoint, port, security_group_id 등

**완료 기준**:
- 모듈 코드 작성 완료
- terraform plan 성공
- README 및 예제 작성

**스토리 포인트**: 5

---

#### TASK 4-4: ALB 모듈 개발
**목표**: Application Load Balancer 생성 모듈

**작업 내용**:
- ALB
  - 입력: VPC, Subnets (Public), Security Group
  - 내부/외부 선택
- Listener
  - HTTP (80) → HTTPS (443) 리다이렉트
  - HTTPS Listener + SSL 인증서
- Target Group
  - Health Check 경로, 포트
  - Deregistration Delay
- Listener Rules
  - Path 기반 라우팅 (선택)
  - Host 기반 라우팅 (선택)
- SSL/TLS 인증서
  - ACM 인증서 ARN 입력
  - 또는 자동 생성 옵션
- 입출력 변수
  - 입력: alb_name, vpc_id, subnets, certificate_arn 등
  - 출력: alb_arn, alb_dns_name, target_group_arn 등

**완료 기준**:
- 모듈 코드 작성 완료
- terraform plan 성공
- README 및 예제 작성

**스토리 포인트**: 5

---

#### TASK 4-5: IAM Role/Policy 모듈 개발
**목표**: 공통 IAM Role 및 Policy 템플릿

**작업 내용**:
- ECS Task Role
  - 애플리케이션이 사용하는 권한
  - Secrets Manager 접근
  - S3 접근 (선택)
  - RDS 접근 (IAM Auth 사용 시)
- ECS Execution Role
  - ECR 이미지 풀
  - CloudWatch Logs 작성
  - Secrets Manager 시크릿 읽기
- RDS IAM Auth Policy
  - RDS에 IAM 인증으로 접근
- S3 Access Policy
  - 특정 버킷 읽기/쓰기 권한
- Policy 템플릿
  - 최소 권한 원칙 적용
  - 리소스 ARN 변수화
- 입출력 변수
  - 입력: role_name, policies (list), trust_policy 등
  - 출력: role_arn, role_name 등

**완료 기준**:
- 모듈 코드 작성 완료
- terraform plan 성공
- README 및 예제 작성

**스토리 포인트**: 3

---

#### TASK 4-6: Security Group 모듈 개발
**목표**: 공통 Security Group 패턴 모듈

**작업 내용**:
- ALB Security Group
  - Ingress: 80 (0.0.0.0/0), 443 (0.0.0.0/0)
  - Egress: All (ECS로)
- ECS Security Group
  - Ingress: ALB SG에서만
  - Egress: All (외부 API 호출용)
- RDS Security Group
  - Ingress: ECS SG에서만
  - Egress: None
- VPC Endpoint Security Group (선택)
  - S3, ECR, Secrets Manager
- 커스터마이징 옵션
  - 추가 Ingress/Egress 규칙
- 입출력 변수
  - 입력: sg_name, vpc_id, ingress_rules, egress_rules 등
  - 출력: security_group_id 등

**완료 기준**:
- 모듈 코드 작성 완료
- terraform plan 성공
- README 및 예제 작성

**스토리 포인트**: 3

---

#### TASK 4-7: 모듈 예제 작성
**목표**: 각 모듈의 실제 사용 예제

**작업 내용**:
- `examples/` 폴더 구조
  ```
  examples/
  ├── ecs-service-basic/
  │   ├── main.tf
  │   ├── variables.tf
  │   └── README.md
  ├── rds-postgresql/
  ├── alb-multi-target/
  └── ...
  ```
- 각 예제에 포함할 내용
  - 실제 사용 가능한 Terraform 코드
  - terraform plan 출력 (예상 리소스)
  - 설명 및 주의사항
- 복합 예제
  - ECS + RDS + ALB 전체 스택
  - 환경별 설정 차이 (dev vs prod)

**완료 기준**:
- 각 모듈별 예제 1개 이상 작성
- terraform plan 성공
- README 작성

**스토리 포인트**: 3

---

#### TASK 4-8: 모듈 버전 태그 및 릴리스
**목표**: 첫 안정 버전 릴리스

**작업 내용**:
- 모든 모듈 검토
  - 코드 리뷰
  - 테스트 검증
- CHANGELOG.md 작성
  - v1.0.0: Initial stable release
  - 각 모듈별 기능 목록
- UPGRADE.md 작성
  - v0.x → v1.0.0 마이그레이션 가이드
  - Breaking changes (해당 시)
- Git 태그 생성
  ```bash
  git tag -a v1.0.0 -m "First stable release"
  git push origin v1.0.0
  ```
- GitHub Release 생성
  - Release Notes 작성
  - CHANGELOG 링크
  - 사용 가이드 링크

**완료 기준**:
- v1.0.0 태그 생성
- GitHub Release 게시
- 문서 링크 정리

**스토리 포인트**: 2

---

### EPIC 5: 가드레일 및 정책 검증
**목적**: 서비스 레포 PR의 보안/정책/비용 자동 검증
**우선순위**: P1
**레이블**: `infra`, `security`, `policy`, `cost`, `guardrails`

#### TASK 5-1: tfsec 보안 스캔 설정
**목표**: Terraform 코드 보안 취약점 자동 검사

**작업 내용**:
- tfsec 설정 파일 생성
  - `.tfsec/config.yml`
  - 검사 규칙 활성화/비활성화
- 최소 보안 기준선 정의
  - S3 버킷 암호화 필수
  - RDS 암호화 필수
  - Security Group 0.0.0.0/0 금지 (특정 포트 제외)
  - IAM Policy 와일드카드 제한
- GitHub Actions 워크플로우
  - PR 시 자동 실행
  - 결과를 PR 코멘트로 표시
- 결과 리포팅 템플릿
  - 심각도별 분류 (CRITICAL, HIGH, MEDIUM, LOW)
  - 수정 방법 가이드 링크

**완료 기준**:
- tfsec 설정 완료
- GitHub Actions 통합
- 예제 PR에서 검증 성공

**스토리 포인트**: 3

---

#### TASK 5-2: checkov 정책 검증 설정
**목표**: IaC 베스트 프랙티스 자동 검증

**작업 내용**:
- checkov 설정 파일
  - `.checkov.yml`
  - AWS Best Practices 체크리스트
- CIS Benchmark 적용
  - CIS AWS Foundations Benchmark
  - 관련 규칙 활성화
- Skip 규칙 관리
  - 특정 리소스 예외 처리 방법
  - 예외 승인 프로세스
- GitHub Actions 통합
  - tfsec와 함께 실행
  - 결과 통합 리포팅

**완료 기준**:
- checkov 설정 완료
- CIS Benchmark 검증
- 예제 PR에서 검증 성공

**스토리 포인트**: 3

---

#### TASK 5-3: OPA/Conftest In-Repo 정책 작성
**목표**: 조직 특화 정책 자동 검증

**작업 내용**:
- `policy/` 디렉터리 생성
  ```
  policy/
  ├── tags.rego
  ├── naming.rego
  ├── security_groups.rego
  └── public_resources.rego
  ```
- 필수 태그 검증 정책
  - Environment, Service, Team, Owner 태그 필수
  - 태그 값 형식 검증
- 네이밍 규약 검증 정책
  - `{env}-{service}-{resource}` 패턴 강제
- 보안 그룹 규칙 검증
  - 0.0.0.0/0 금지 (ALB 제외)
  - 불필요한 포트 개방 금지
- 퍼블릭 리소스 차단 정책
  - S3 버킷 퍼블릭 접근 금지
  - RDS 퍼블릭 접근 금지
- Conftest 통합
  - terraform plan → JSON → Conftest 검증

**완료 기준**:
- 4개 정책 파일 작성
- Conftest 통합 완료
- 예제 PR에서 검증 성공

**스토리 포인트**: 5

---

#### TASK 5-4: Infracost 비용 검증 설정
**목표**: Terraform 변경 시 예상 비용 자동 계산

**작업 내용**:
- Infracost API Key 설정
  - Secrets Manager 또는 GitHub Secrets
- 비용 임계치 정의
  - +10% 증가: 경고 (Warning)
  - +30% 증가: 차단 (Block, 추가 승인 필요)
- PR 코멘트 자동화
  - 변경 전/후 비용 비교
  - 증가/감소 금액 및 비율
  - 주요 비용 항목 (ECS, RDS, ALB 등)
- 비용 리포트 템플릿
  - 월별 예상 비용
  - 리소스별 비용 분석

**완료 기준**:
- Infracost 통합 완료
- PR 코멘트 생성 확인
- 임계치 검증 테스트

**스토리 포인트**: 3

---

#### TASK 5-5: GitHub Actions 워크플로우 템플릿
**목표**: 서비스 레포에서 사용할 통합 워크플로우

**작업 내용**:
- `infra-checks.yml` 템플릿 작성
  ```yaml
  name: Infrastructure Checks
  on: [pull_request]
  jobs:
    security:
      - tfsec
      - checkov
    policy:
      - conftest
    cost:
      - infracost
  ```
- 통합 리포팅
  - 모든 검사 결과를 하나의 PR 코멘트로
  - 통과/실패 상태 요약
- 실패 시 동작
  - PR Merge 차단
  - 예외 승인 프로세스 (Override)
- 서비스 레포 적용 가이드
  - 워크플로우 파일 복사 방법
  - Secrets 설정 방법
  - 커스터마이징 옵션

**완료 기준**:
- 워크플로우 템플릿 작성
- 통합 테스트 성공
- 적용 가이드 문서화

**스토리 포인트**: 3

---

### EPIC 6: 문서화 및 온보딩
**목적**: 서비스 팀이 자율적으로 인프라를 구축할 수 있도록 지원
**우선순위**: P2
**레이블**: `infra`, `documentation`, `onboarding`, `guide`

#### TASK 6-1: 서비스 레포 온보딩 가이드
**목표**: 새 서비스 팀이 인프라를 시작할 수 있는 가이드

**작업 내용**:
- infra/ 폴더 구조 가이드
  ```
  서비스레포/
  └── infra/
      ├── environments/
      │   ├── dev/
      │   │   ├── main.tf
      │   │   ├── backend.tf
      │   │   ├── variables.tf
      │   │   └── dev.tfvars
      │   └── prod/
      ├── modules/ (로컬 모듈, 선택)
      └── atlantis.yaml
  ```
- 중앙 모듈 참조 방법
  ```hcl
  module "ecs_service" {
    source = "git::https://github.com/org/infrastructure.git//modules/ecs_service?ref=v1.0.0"
    # 변수 전달
  }
  ```
- backend.tf 작성 가이드
  - S3 버킷, DynamoDB 테이블 정보
  - Key 경로 규칙: `{service}/{env}/terraform.tfstate`
- atlantis.yaml 작성 가이드
  - 프로젝트 설정
  - Workflow 커스터마이징
- 첫 PR 만들기 튜토리얼
  - Step-by-step 가이드
  - 예상 Atlantis 출력
  - Apply 승인 프로세스

**완료 기준**:
- 온보딩 가이드 문서화
- 튜토리얼 검증
- Notion/Wiki 게시

**스토리 포인트**: 3

---

#### TASK 6-2: 모듈 사용 가이드
**목표**: 각 모듈의 상세 사용 방법

**작업 내용**:
- 각 모듈별 사용 예제
  - 최소 구성 예제
  - 프로덕션 권장 구성
- 변수 설명 및 기본값
  - 필수 변수
  - 선택 변수 및 기본값
  - 변수 타입 및 제약사항
- 일반적인 사용 패턴
  - dev vs prod 설정 차이
  - AutoScaling 설정 방법
  - Multi-AZ 구성 방법
- 트러블슈팅 FAQ
  - 자주 발생하는 에러
  - 해결 방법
  - 지원 요청 방법

**완료 기준**:
- 각 모듈별 가이드 작성
- 예제 코드 검증
- FAQ 최소 5개 항목

**스토리 포인트**: 3

---

#### TASK 6-3: 운영 런북
**목표**: 일상 운영 시나리오별 절차 문서

**작업 내용**:
- 릴리스 프로세스
  - 코드 + 인프라 동시 배포 절차
  - Blue/Green 배포 (선택)
  - 롤링 업데이트
- 롤백 절차
  - Terraform 상태 롤백
  - 애플리케이션 이미지 롤백
  - 데이터베이스 마이그레이션 롤백
- 핫픽스 프로세스
  - 긴급 변경 승인 프로세스
  - Atlantis Plan Skip (허용 조건)
  - 사후 PR 작성
- 드리프트 해결 방법
  - Import vs 재적용 판단
  - terraform import 가이드
  - 드리프트 방지 팁
- 스케일링 가이드
  - ECS Task 수 조정
  - RDS 인스턴스 타입 변경
  - 비용 영향 분석

**완료 기준**:
- 런북 문서 작성
- 각 절차 검증
- Notion/Wiki 게시

**스토리 포인트**: 3

---

#### TASK 6-4: PR 템플릿 및 체크리스트
**목표**: 일관된 PR 프로세스 및 품질 관리

**작업 내용**:
- PULL_REQUEST_TEMPLATE.md 작성
  ```markdown
  ## 변경 내용
  - [ ] 새 리소스 추가
  - [ ] 기존 리소스 수정
  - [ ] 리소스 삭제

  ## 체크리스트
  - [ ] terraform fmt 실행
  - [ ] tfsec/checkov 통과
  - [ ] Infracost 비용 확인
  - [ ] Atlantis plan 검토

  ## 영향 범위
  - 환경: dev / stg / prod
  - 서비스:
  ```
- ISSUE_TEMPLATE/ 작성
  - `bug.md`: 인프라 버그 리포트
  - `feature.md`: 새 리소스 요청
  - `infrastructure.md`: 인프라 변경 제안
- CODEOWNERS 예제
  ```
  /infra/ @platform-team
  /infra/environments/prod/ @platform-team @security-team
  ```
- PR 리뷰 체크리스트
  - 보안 검토 항목
  - 비용 검토 항목
  - 성능 검토 항목

**완료 기준**:
- 템플릿 파일 작성
- 서비스 레포 적용 가이드
- 예제 PR 생성 및 검증

**스토리 포인트**: 2

---

## 📊 Epic & Task 요약

| Epic | Task 수 | 총 SP | 우선순위 | 상태 |
|------|---------|-------|---------|------|
| EPIC 1: Atlantis 플랫폼 | 6 | 20 | P1 | 계획 |
| EPIC 2: 공통 플랫폼 인프라 | 7 | 20 | P1 | 계획 |
| EPIC 3: 중앙 관측성 시스템 | 5 | 19 | P1 | 계획 |
| EPIC 4: 재사용 가능한 표준 모듈 | 8 | 28 | P1 | 계획 |
| EPIC 5: 가드레일 및 정책 검증 | 5 | 17 | P1 | 계획 |
| EPIC 6: 문서화 및 온보딩 | 4 | 11 | P2 | 계획 |
| **합계** | **35** | **115** | - | - |

---

## 🗓️ 권장 타임라인

**Phase 1 (Week 1-2)**: EPIC 1 완료
- Atlantis 플랫폼이 가장 중요한 기반

**Phase 2 (Week 3-4)**: EPIC 2, EPIC 4 병행
- 플랫폼 인프라 + 모듈 개발 동시 진행

**Phase 3 (Week 5)**: EPIC 5 완료
- 가드레일 구축

**Phase 4 (Week 6)**: EPIC 3 완료
- 관측성 시스템 (병행 가능)

**Phase 5 (Week 7)**: EPIC 6 완료
- 문서화 및 서비스 레포 온보딩

---

## 🔄 서비스 레포 작업 (중앙 레포 완료 후)

각 서비스 레포(FileFlow, CrawlingHub, AuthHub)가 할 일:

### 전제 조건
- ✅ 중앙 레포 v1.0.0 릴리스
- ✅ Atlantis allowlist 등록
- ✅ Terraform State 백엔드 준비
- ✅ IAM AssumeRole 권한 설정

### 6단계 온보딩

**1단계: 레포 구조 생성** (1 SP)
- `infra/` 폴더 및 하위 구조 생성

**2단계: Terraform 설정 파일** (2 SP)
- versions.tf, providers.tf, backend.tf, variables.tf, tfvars

**3단계: 중앙 모듈 참조** (3 SP)
- ECS, RDS, ALB 모듈 호출 및 변수 전달

**4단계: atlantis.yaml 작성** (1 SP)
- 프로젝트 및 워크플로우 설정

**5단계: GitHub Actions 추가** (2 SP)
- infra-checks.yml 복사 및 Secrets 설정

**6단계: 첫 PR 및 배포** (3 SP)
- PR 생성 → Atlantis plan → 검증 통과 → Apply

**서비스 레포 온보딩 총 SP**: 12 SP (서비스당)

---

## 📝 다음 단계

1. **Jira Epic/Task 생성**
   - 이 문서를 기반으로 Jira에 등록
   - CSV Import 또는 수동 생성

2. **우선순위 조정**
   - 팀 상황에 맞춰 Epic 순서 조정

3. **담당자 할당**
   - 각 Task에 담당자 지정

4. **Sprint 계획**
   - 2주 Sprint 기준으로 Task 분배
