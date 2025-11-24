# Changelog

All notable changes to the Lambda module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-23

### Added

#### 핵심 기능
- AWS Lambda 함수 생성 및 관리 기능
- 로컬 파일(`filename`) 및 S3(`s3_bucket`) 배포 지원
- IAM 역할 자동 생성 및 관리 (`create_role`)
- VPC 통합 지원 (`vpc_config`)
- CloudWatch Logs 자동 생성 및 KMS 암호화 지원
- Dead Letter Queue (SQS) 생성 및 권한 설정
- X-Ray 분산 추적 지원 (`tracing_mode`)
- Lambda 함수 별칭(Alias) 및 가중치 기반 라우팅
- Lambda 권한 관리 (다른 AWS 서비스 호출 허용)
- Lambda 계층(Layers) 연결 지원

#### 런타임 지원
- Python: `python3.9`, `python3.10`, `python3.11`, `python3.12`
- Node.js: `nodejs18.x`, `nodejs20.x`
- Java: `java17`, `java21`
- .NET: `dotnet6`, `dotnet8`
- Go: `go1.x`
- Ruby: `ruby3.2`, `ruby3.3`

#### 아키텍처 지원
- x86_64 (Intel/AMD)
- arm64 (AWS Graviton2)

#### 리소스 설정
- 메모리: 128MB ~ 10,240MB (10GB)
- 타임아웃: 1초 ~ 900초 (15분)
- 임시 스토리지: 512MB ~ 10,240MB
- 예약된 동시 실행 수 설정

#### IAM 및 권한
- 기본 실행 역할 자동 생성
- VPC 실행 역할 자동 연결 (VPC 설정 시)
- 커스텀 정책 ARN 연결 지원 (`custom_policy_arns`)
- 인라인 정책 지원 (`inline_policy`)
- DLQ 접근 권한 자동 설정
- 기존 IAM 역할 사용 옵션 (`lambda_role_arn`)

#### 로깅 및 모니터링
- CloudWatch Log Group 자동 생성
- 로그 보존 기간 설정 (1일 ~ 10년)
- KMS 암호화 로그 그룹 지원
- X-Ray Active 및 PassThrough 모드

#### Dead Letter Queue
- SQS 기반 DLQ 자동 생성
- 메시지 보존 기간 설정 (60초 ~ 14일)
- KMS 암호화 지원
- Visibility timeout 설정

#### 버전 관리 및 배포
- Lambda 함수 버전 게시 (`publish`)
- 별칭(Alias) 생성 및 관리
- 가중치 기반 트래픽 라우팅 (Canary/Blue-Green)
- 소스 코드 해시 추적 (`source_code_hash`)

#### 태그 및 거버넌스
- `common-tags` 모듈 통합
- 필수 태그 자동 적용 (Owner, CostCenter, Environment 등)
- 리소스별 커스텀 태그 지원
- 추가 태그 병합 기능 (`additional_tags`)

#### 검증 및 제약 조건
- 배포 소스 배타성 검증 (로컬 파일 vs S3)
- 로컬 배포 시 해시 필수 검증
- IAM 역할 요구사항 검증
- 코드 소스 필수 검증
- 런타임 유효성 검증
- 아키텍처 유효성 검증
- 메모리/타임아웃 범위 검증
- 로그 보존 기간 유효성 검증
- 추적 모드 유효성 검증

#### 출력 값
- Lambda 함수 정보 (name, arn, invoke_arn, version 등)
- IAM 역할 정보 (arn, name, id)
- CloudWatch Log Group 정보
- DLQ 정보 (arn, url)
- 별칭 정보 맵
- 권한 정보 맵

#### 의존성 관리
- CloudWatch Log Group 우선 생성
- IAM 역할 및 정책 연결 후 Lambda 함수 생성
- 순환 의존성 방지 구조

### Configuration

#### 필수 변수
- `environment`: 환경 이름 (dev, staging, prod)
- `service`: 서비스 이름
- `team`: 담당 팀
- `owner`: 소유자 이메일
- `cost_center`: 비용 센터
- `name`: Lambda 함수 이름 접미사
- `handler`: Lambda 함수 핸들러
- `runtime`: Lambda 런타임

#### 선택적 변수
- `function_name`: 전체 함수 이름 재정의
- `description`: 함수 설명
- `architectures`: CPU 아키텍처 (기본: x86_64)
- `timeout`: 타임아웃 (기본: 30초)
- `memory_size`: 메모리 크기 (기본: 128MB)
- `reserved_concurrent_executions`: 예약 동시 실행 (기본: -1)
- `filename`: 로컬 배포 파일 경로
- `s3_bucket`: S3 배포 버킷
- `s3_key`: S3 배포 키
- `s3_object_version`: S3 객체 버전
- `source_code_hash`: 소스 코드 해시
- `layers`: Lambda 계층 ARN 목록
- `publish`: 버전 게시 여부 (기본: false)
- `environment_variables`: 환경 변수 맵
- `vpc_config`: VPC 설정
- `create_role`: IAM 역할 생성 여부 (기본: true)
- `lambda_role_arn`: 기존 IAM 역할 ARN
- `custom_policy_arns`: 커스텀 정책 ARN 맵
- `inline_policy`: 인라인 정책 JSON
- `create_log_group`: 로그 그룹 생성 여부 (기본: true)
- `log_retention_days`: 로그 보존 기간 (기본: 14일)
- `log_kms_key_id`: 로그 암호화 KMS 키
- `create_dlq`: DLQ 생성 여부 (기본: false)
- `dlq_message_retention_seconds`: DLQ 메시지 보존 (기본: 14일)
- `dlq_kms_key_id`: DLQ 암호화 KMS 키
- `dlq_visibility_timeout_seconds`: DLQ visibility timeout (기본: 300초)
- `tracing_mode`: X-Ray 추적 모드
- `ephemeral_storage_size`: 임시 스토리지 크기
- `aliases`: 별칭 설정 맵
- `lambda_permissions`: 권한 설정 맵
- `project`: 프로젝트 이름 (기본: "infrastructure")
- `data_class`: 데이터 분류 (기본: "confidential")
- `additional_tags`: 추가 태그 맵

### Technical Details

#### Terraform 버전
- Terraform: >= 1.5.0
- AWS Provider: >= 5.0

#### 생성 리소스
- `aws_lambda_function.this`: Lambda 함수 (1개)
- `aws_iam_role.lambda`: IAM 역할 (0-1개)
- `aws_iam_role_policy_attachment.basic-execution`: 기본 실행 정책 (0-1개)
- `aws_iam_role_policy_attachment.vpc-execution`: VPC 실행 정책 (0-1개)
- `aws_iam_role_policy_attachment.custom`: 커스텀 정책 연결 (0-N개)
- `aws_iam_role_policy.inline`: 인라인 정책 (0-1개)
- `aws_iam_policy.dlq`: DLQ 정책 (0-1개)
- `aws_iam_role_policy_attachment.dlq`: DLQ 정책 연결 (0-1개)
- `aws_cloudwatch_log_group.lambda`: 로그 그룹 (0-1개)
- `aws_sqs_queue.dlq`: DLQ (0-1개)
- `aws_lambda_alias.this`: 별칭 (0-N개)
- `aws_lambda_permission.this`: 권한 (0-N개)

#### 명명 규칙
- Lambda 함수: `{service}-{environment}-{name}` (또는 `function_name` 재정의)
- IAM 역할: `{function_name}-role`
- CloudWatch Log Group: `/aws/lambda/{function_name}`
- DLQ: `{function_name}-dlq`
- 인라인 정책: `{function_name}-inline-policy`
- DLQ 정책: `{function_name}-dlq-policy`

### Security

#### 보안 기능
- KMS 암호화 CloudWatch Logs 지원
- KMS 암호화 DLQ 지원
- VPC 격리 지원
- 최소 권한 IAM 역할
- 명시적 권한 부여 메커니즘
- X-Ray 추적을 통한 가시성

#### 권장 사항
- 프로덕션 환경에서 `log_kms_key_id` 설정
- 프로덕션 환경에서 `create_dlq = true` 설정
- DLQ에 대한 모니터링 및 알람 설정
- VPC 내부 리소스 접근 시 적절한 보안 그룹 구성
- 최소 권한 원칙에 따른 IAM 정책 설정
- `publish = true`를 통한 버전 관리
- 별칭을 활용한 안전한 배포 전략

### Documentation
- 한국어 README.md 작성
- 6가지 상세 사용 예시 제공
  1. 기본 사용 (로컬 파일 배포)
  2. S3 배포 및 VPC 설정
  3. 별칭을 활용한 Blue/Green 배포
  4. EventBridge 호출 권한 부여
  5. 기존 IAM 역할 사용
  6. 대용량 메모리 및 임시 스토리지 설정
- 전체 입력 변수 문서화
- 전체 출력 값 문서화
- 리소스 생성 조건 명시
- 거버넌스 및 보안 가이드라인
- 호환성 정보
- 개발 가이드

### Notes
- 이 모듈은 `common-tags` 모듈에 의존합니다
- 기본적으로 필요한 최소 권한만 부여되며, 추가 권한은 명시적으로 설정해야 합니다
- VPC 설정 시 콜드 스타트 시간이 증가할 수 있습니다
- Graviton2 (arm64) 아키텍처 사용 시 비용 절감 효과가 있습니다
- 별칭 리소스는 태그를 지원하지 않습니다 (AWS 제한사항)

[1.0.0]: https://github.com/your-org/infrastructure/releases/tag/lambda-v1.0.0
