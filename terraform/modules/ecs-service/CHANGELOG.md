# Changelog

이 파일은 `ecs-service` 모듈의 모든 주요 변경사항을 문서화합니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/)를 따르며,
이 프로젝트는 [Semantic Versioning](https://semver.org/lang/ko/)을 준수합니다.

## [1.0.0] - 2025-11-23

### 추가됨

#### 핵심 기능
- AWS Fargate 기반 ECS 서비스 프로비저닝 지원
- ECS Task Definition 자동 생성 및 관리
- CloudWatch Logs 통합 로깅 (기본 7일 보존)
- CPU/메모리 기반 Auto Scaling 지원
- ALB Target Group 연동 지원
- 배포 Circuit Breaker 및 자동 롤백 기능

#### 컨테이너 설정
- 환경변수 주입 (`container_environment`)
- Secrets Manager/Parameter Store 시크릿 주입 (`container_secrets`)
- 컨테이너 헬스체크 설정 (`health_check_command`)
- ECS Exec 지원 (SSH 대체, `enable_execute_command`)
- 커스텀 로그 드라이버 설정 (`log_configuration`)

#### 배포 안전성
- 배포 Circuit Breaker 기본 활성화
- 배포 실패 시 자동 롤백 (기본 활성화)
- 배포 최대/최소 정상 태스크 비율 설정
- ALB 헬스체크 유예 시간 설정

#### Auto Scaling
- CPU 사용률 기반 Auto Scaling
- 메모리 사용률 기반 Auto Scaling
- 최소/최대 태스크 수 설정
- Scale-in/Scale-out Cooldown 기간 설정 (Scale-in: 300초, Scale-out: 60초)

#### 태그 및 거버넌스
- `common-tags` 모듈 통합으로 표준 태그 자동 적용
- 필수 거버넌스 태그 검증 (Environment, Service, Team, Owner, CostCenter)
- 추가 태그 병합 지원 (`additional_tags`)
- ECS 관리형 태그 지원
- 태그 전파 옵션 (TASK_DEFINITION, SERVICE, NONE)

#### 검증 규칙
- 컨테이너/서비스 이름 kebab-case 검증
- CPU 유효값 검증 (256, 512, 1024, 2048, 4096, 8192, 16384)
- 컨테이너 포트 범위 검증 (1-65535)
- 헬스체크 파라미터 범위 검증
- Auto Scaling 설정 검증 (min_capacity ≤ max_capacity)
- 배포 설정 범위 검증
- 환경 유효값 검증 (dev, staging, prod)
- 태그 명명 규칙 검증 (kebab-case)

### 출력값

#### 서비스 식별자
- `service_id`: ECS 서비스 ID
- `service_name`: ECS 서비스 이름
- `task_definition_arn`: Task Definition 전체 ARN

#### Task Definition
- `task_definition_family`: Task Definition Family 이름
- `task_definition_revision`: Task Definition 리비전 번호

#### 컨테이너 정보
- `container_name`: 컨테이너 이름
- `container_port`: 컨테이너 포트

#### CloudWatch Logs
- `cloudwatch_log_group_arn`: Log Group ARN (모듈 생성 시)
- `cloudwatch_log_group_name`: Log Group 이름 (모듈 생성 시)

#### Auto Scaling
- `autoscaling_target_id`: Auto Scaling Target ID (활성화 시)
- `autoscaling_cpu_policy_arn`: CPU Auto Scaling 정책 ARN (활성화 시)
- `autoscaling_memory_policy_arn`: 메모리 Auto Scaling 정책 ARN (활성화 시)

#### 기타
- `service_cluster`: 서비스 실행 클러스터
- `service_desired_count`: 서비스 desired_count

### 기술 세부사항

#### 리소스 생성
- `aws_ecs_task_definition`: Fargate Task Definition (필수)
- `aws_ecs_service`: ECS 서비스 (필수)
- `aws_cloudwatch_log_group`: CloudWatch Log Group (조건부 - log_configuration이 null인 경우)
- `aws_appautoscaling_target`: Auto Scaling 대상 (조건부 - enable_autoscaling=true)
- `aws_appautoscaling_policy`: CPU Auto Scaling 정책 (조건부)
- `aws_appautoscaling_policy`: 메모리 Auto Scaling 정책 (조건부)

#### 기본 설정값
- Network Mode: `awsvpc` (고정)
- Launch Type: `FARGATE` (고정)
- Log Retention: 7일
- Deployment Maximum Percent: 200%
- Deployment Minimum Healthy Percent: 100%
- Circuit Breaker: 활성화 + 롤백
- ECS Managed Tags: 활성화
- Tag Propagation: SERVICE
- Auto Scaling CPU Target: 70%
- Auto Scaling Memory Target: 80%
- Scale-in Cooldown: 300초
- Scale-out Cooldown: 60초

### 보안

#### IAM 역할 분리
- Execution Role: ECR 이미지 pull, Secrets Manager/Parameter Store 접근, CloudWatch Logs 쓰기
- Task Role: 컨테이너 애플리케이션 권한

#### 시크릿 관리
- Secrets Manager 통합
- Parameter Store 통합
- 환경변수 하드코딩 방지

### 운영

#### 로깅
- CloudWatch Logs 자동 통합
- Log Group 자동 생성 (커스텀 설정 가능)
- 로그 보존 기간 설정 (1일 ~ 10년)

#### 모니터링
- CloudWatch Container Insights 지원 (기본 활성화)
- Auto Scaling 메트릭 자동 수집
- 배포 이벤트 추적

#### 배포 전략
- Rolling Update (기본)
- Circuit Breaker를 통한 배포 안전성 보장
- 자동 롤백으로 장애 최소화

### 호환성

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0
- 종속 모듈: `common-tags` 모듈

### 문서화

- 한국어 README.md 작성
- 6가지 사용 예시 제공 (기본, ALB, Auto Scaling, 환경변수/시크릿, 헬스체크, ECS Exec)
- CPU/메모리 조합 가이드 제공
- 운영 가이드 (접속, 로그, Auto Scaling, 배포 모니터링)
- 트러블슈팅 가이드 (Task 시작 실패, Auto Scaling 문제, 배포 실패)

### 알려진 제약사항

- Fargate만 지원 (EC2 Launch Type 미지원)
- awsvpc 네트워크 모드만 지원
- CPU/메모리는 Fargate 지원 조합만 사용 가능
- Auto Scaling은 CPU/메모리 메트릭만 지원 (커스텀 메트릭 미지원)

[1.0.0]: https://github.com/your-org/infrastructure/releases/tag/ecs-service-v1.0.0
