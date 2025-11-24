# ECS Service 모듈

AWS Fargate 기반 ECS 서비스를 프로비저닝하는 Terraform 모듈입니다. Task Definition, Service, Auto Scaling, CloudWatch Logs를 통합 관리하며, 거버넌스 표준을 준수합니다.

## 주요 기능

- ✅ **Fargate 기반 배포**: 서버리스 컨테이너 실행 환경
- ✅ **통합 로깅**: CloudWatch Logs 자동 구성 (기본 7일 보존)
- ✅ **Auto Scaling**: CPU/메모리 기반 자동 확장 (선택적)
- ✅ **배포 안전성**: Circuit Breaker 기본 활성화 및 롤백 지원
- ✅ **헬스체크**: 컨테이너 및 ALB 헬스체크 구성
- ✅ **보안 통합**: Secrets Manager/Parameter Store 연동
- ✅ **거버넌스 준수**: 필수 태그 및 명명 규칙 자동 적용

## 사용 예시

### 기본 사용법

```hcl
module "api_service" {
  source = "../../modules/ecs-service"

  # 필수: 서비스 식별 정보
  name           = "api-server"
  cluster_id     = aws_ecs_cluster.main.id

  # 필수: 컨테이너 설정
  container_name  = "api-server"
  container_image = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/api-server:latest"
  container_port  = 8080

  # 필수: 컴퓨팅 리소스
  cpu    = 512
  memory = 1024

  # 필수: IAM 역할
  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  # 필수: 네트워크 설정
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]

  # 필수: 태그 정보
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  # 선택: 태스크 수
  desired_count = 2
}
```

### ALB 연동

```hcl
module "web_service" {
  source = "../../modules/ecs-service"

  name           = "web-app"
  cluster_id     = aws_ecs_cluster.main.id
  container_name = "web-app"
  container_image = "nginx:latest"
  container_port = 80

  cpu    = 256
  memory = 512

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]

  # ALB 설정
  load_balancer_config = {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "web-app"
    container_port   = 80
  }
  health_check_grace_period_seconds = 60

  environment  = "prod"
  service_name = "web-app"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

### Auto Scaling 활성화

```hcl
module "worker_service" {
  source = "../../modules/ecs-service"

  name           = "worker"
  cluster_id     = aws_ecs_cluster.main.id
  container_name = "worker"
  container_image = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/worker:latest"
  container_port = 8080

  cpu    = 1024
  memory = 2048

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]

  desired_count = 2

  # Auto Scaling 설정
  enable_autoscaling       = true
  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 10
  autoscaling_target_cpu   = 70
  autoscaling_target_memory = 80

  environment  = "prod"
  service_name = "worker"
  team         = "data-team"
  owner        = "data@example.com"
  cost_center  = "engineering"
}
```

### 환경변수 및 시크릿 주입

```hcl
module "app_service" {
  source = "../../modules/ecs-service"

  name           = "app"
  cluster_id     = aws_ecs_cluster.main.id
  container_name = "app"
  container_image = "app:latest"
  container_port = 3000

  cpu    = 512
  memory = 1024

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]

  # 환경변수
  container_environment = [
    {
      name  = "NODE_ENV"
      value = "production"
    },
    {
      name  = "PORT"
      value = "3000"
    }
  ]

  # 시크릿 (Secrets Manager/Parameter Store)
  container_secrets = [
    {
      name      = "DB_PASSWORD"
      valueFrom = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:db-password"
    },
    {
      name      = "API_KEY"
      valueFrom = "arn:aws:ssm:ap-northeast-2:123456789012:parameter/api-key"
    }
  ]

  environment  = "prod"
  service_name = "app"
  team         = "backend-team"
  owner        = "backend@example.com"
  cost_center  = "engineering"
}
```

### 헬스체크 설정

```hcl
module "api_service" {
  source = "../../modules/ecs-service"

  name           = "api"
  cluster_id     = aws_ecs_cluster.main.id
  container_name = "api"
  container_image = "api:latest"
  container_port = 8080

  cpu    = 512
  memory = 1024

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]

  # 컨테이너 헬스체크
  health_check_command = [
    "CMD-SHELL",
    "curl -f http://localhost:8080/health || exit 1"
  ]
  health_check_interval     = 30
  health_check_timeout      = 5
  health_check_retries      = 3
  health_check_start_period = 60

  environment  = "prod"
  service_name = "api"
  team         = "backend-team"
  owner        = "backend@example.com"
  cost_center  = "engineering"
}
```

### ECS Exec 활성화 (디버깅용)

```hcl
module "debug_service" {
  source = "../../modules/ecs-service"

  name           = "debug-app"
  cluster_id     = aws_ecs_cluster.main.id
  container_name = "debug-app"
  container_image = "app:debug"
  container_port = 8080

  cpu    = 256
  memory = 512

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.ecs_tasks.id]

  # ECS Exec 활성화 (aws ecs execute-command 사용 가능)
  enable_execute_command = true

  environment  = "dev"
  service_name = "debug-app"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

## 입력 변수

### 필수 변수

#### 서비스 설정

| 변수명 | 타입 | 설명 | 제약사항 |
|--------|------|------|----------|
| `name` | string | ECS 서비스 및 Task Definition 이름 | 소문자, 숫자, 하이픈만 사용 (kebab-case) |
| `cluster_id` | string | ECS 클러스터 ID | - |
| `desired_count` | number | 실행할 태스크 수 | 기본값: 1, ≥0 |

#### 컨테이너 설정

| 변수명 | 타입 | 설명 | 제약사항 |
|--------|------|------|----------|
| `container_name` | string | 컨테이너 이름 | 소문자, 숫자, 하이픈만 사용 |
| `container_image` | string | Docker 이미지 URL | ECR URL 또는 Docker Hub 이미지 |
| `container_port` | number | 컨테이너 포트 | 1-65535 |
| `cpu` | number | CPU 단위 | 256, 512, 1024, 2048, 4096, 8192, 16384 중 선택 |
| `memory` | number | 메모리 (MiB) | >0 |

#### IAM 역할

| 변수명 | 타입 | 설명 |
|--------|------|------|
| `execution_role_arn` | string | ECS Task Execution Role ARN (이미지 pull, 시크릿 접근) |
| `task_role_arn` | string | ECS Task Role ARN (컨테이너 애플리케이션 권한) |

#### 네트워크 설정

| 변수명 | 타입 | 설명 |
|--------|------|------|
| `subnet_ids` | list(string) | ECS 태스크 배포 서브넷 ID 목록 |
| `security_group_ids` | list(string) | 보안 그룹 ID 목록 |

#### 태그 (거버넌스 필수)

| 변수명 | 타입 | 설명 | 제약사항 |
|--------|------|------|----------|
| `environment` | string | 환경 이름 | dev, staging, prod 중 선택 |
| `service_name` | string | 서비스 이름 | kebab-case |
| `team` | string | 담당 팀 | kebab-case |
| `owner` | string | 소유자 이메일 또는 식별자 | 이메일 형식 또는 kebab-case |
| `cost_center` | string | 비용 센터 | kebab-case |

### 선택 변수

#### 컨테이너 설정

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `container_environment` | list(object) | [] | 환경변수 목록 |
| `container_secrets` | list(object) | [] | Secrets Manager/Parameter Store 시크릿 목록 |
| `enable_container_insights` | bool | true | CloudWatch Container Insights 활성화 |
| `enable_execute_command` | bool | false | ECS Exec 활성화 (SSH 대체) |

#### 헬스체크

| 변수명 | 타입 | 기본값 | 설명 | 제약사항 |
|--------|------|--------|------|----------|
| `health_check_command` | list(string) | null | 헬스체크 명령어 | null이면 헬스체크 미설정 |
| `health_check_interval` | number | 30 | 헬스체크 간격(초) | 5-300 |
| `health_check_timeout` | number | 5 | 헬스체크 타임아웃(초) | 2-60 |
| `health_check_retries` | number | 3 | 실패 재시도 횟수 | 1-10 |
| `health_check_start_period` | number | 60 | 헬스체크 시작 유예 시간(초) | 0-300 |

#### 배포 설정

| 변수명 | 타입 | 기본값 | 설명 | 제약사항 |
|--------|------|--------|------|----------|
| `deployment_maximum_percent` | number | 200 | 배포 시 최대 태스크 비율 | 100-200 |
| `deployment_minimum_healthy_percent` | number | 100 | 배포 시 최소 정상 태스크 비율 | 0-100 |
| `deployment_circuit_breaker_enable` | bool | true | 배포 Circuit Breaker 활성화 | - |
| `deployment_circuit_breaker_rollback` | bool | true | 배포 실패 시 자동 롤백 | - |

#### 로드 밸런서

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `load_balancer_config` | object | null | ALB Target Group 설정 |
| `health_check_grace_period_seconds` | number | null | ALB 헬스체크 유예 시간(초) |

#### Auto Scaling

| 변수명 | 타입 | 기본값 | 설명 | 제약사항 |
|--------|------|--------|------|----------|
| `enable_autoscaling` | bool | false | Auto Scaling 활성화 | - |
| `autoscaling_min_capacity` | number | 1 | 최소 태스크 수 | ≥0 |
| `autoscaling_max_capacity` | number | 4 | 최대 태스크 수 | >0, ≥min_capacity |
| `autoscaling_target_cpu` | number | 70 | CPU 목표 사용률(%) | 1-100 |
| `autoscaling_target_memory` | number | 80 | 메모리 목표 사용률(%) | 1-100 |

#### 로깅

| 변수명 | 타입 | 기본값 | 설명 | 제약사항 |
|--------|------|--------|------|----------|
| `log_configuration` | object | null | 커스텀 로그 설정 | null이면 CloudWatch Logs 자동 생성 |
| `log_retention_days` | number | 7 | 로그 보존 기간(일) | CloudWatch Logs 유효한 보존 기간 |

#### 기타

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `assign_public_ip` | bool | false | 퍼블릭 IP 할당 (NAT 없는 퍼블릭 서브넷에서 필요) |
| `enable_ecs_managed_tags` | bool | true | ECS 관리형 태그 활성화 |
| `propagate_tags` | string | "SERVICE" | 태그 전파 방식 (TASK_DEFINITION, SERVICE, NONE) |
| `project` | string | "infrastructure" | 프로젝트 이름 |
| `data_class` | string | "confidential" | 데이터 분류 (confidential, internal, public) |
| `additional_tags` | map(string) | {} | 추가 태그 |

## 출력 값

### 주요 식별자

| 출력명 | 설명 |
|--------|------|
| `service_id` | ECS 서비스 ID |
| `service_name` | ECS 서비스 이름 |
| `task_definition_arn` | Task Definition 전체 ARN |

### 서비스 정보

| 출력명 | 설명 |
|--------|------|
| `service_cluster` | 서비스가 실행 중인 클러스터 |
| `service_desired_count` | 서비스의 desired_count 값 |
| `container_name` | 컨테이너 이름 |
| `container_port` | 컨테이너 포트 |

### Task Definition

| 출력명 | 설명 |
|--------|------|
| `task_definition_family` | Task Definition Family 이름 |
| `task_definition_revision` | Task Definition 리비전 번호 |

### CloudWatch Logs

| 출력명 | 설명 | 조건 |
|--------|------|------|
| `cloudwatch_log_group_arn` | CloudWatch Log Group ARN | 모듈이 생성한 경우만 |
| `cloudwatch_log_group_name` | CloudWatch Log Group 이름 | 모듈이 생성한 경우만 |

### Auto Scaling

| 출력명 | 설명 | 조건 |
|--------|------|------|
| `autoscaling_target_id` | Auto Scaling Target 리소스 ID | Auto Scaling 활성화 시 |
| `autoscaling_cpu_policy_arn` | CPU Auto Scaling 정책 ARN | Auto Scaling 활성화 시 |
| `autoscaling_memory_policy_arn` | 메모리 Auto Scaling 정책 ARN | Auto Scaling 활성화 시 |

## 리소스 생성 목록

이 모듈은 다음 AWS 리소스를 생성합니다:

1. **aws_ecs_task_definition**: Fargate Task Definition
2. **aws_ecs_service**: ECS 서비스
3. **aws_cloudwatch_log_group** (조건부): CloudWatch 로그 그룹 (`log_configuration`이 null인 경우)
4. **aws_appautoscaling_target** (조건부): Auto Scaling 대상 (`enable_autoscaling=true`)
5. **aws_appautoscaling_policy** (조건부): CPU 기반 Auto Scaling 정책
6. **aws_appautoscaling_policy** (조건부): 메모리 기반 Auto Scaling 정책

## 거버넌스 준수

### 필수 태그

모든 리소스에 다음 태그가 자동으로 적용됩니다 (`common-tags` 모듈 사용):

- `Environment`: dev/staging/prod
- `Service`: 서비스 이름
- `Team`: 담당 팀
- `Owner`: 소유자
- `CostCenter`: 비용 센터
- `Project`: 프로젝트 (기본값: infrastructure)
- `DataClass`: 데이터 분류 (기본값: confidential)
- `Lifecycle`: prod/non-prod (환경 기반 자동 결정)
- `ManagedBy`: Terraform
- `Name`: 리소스별 고유 이름
- `Description`: 리소스 설명

### 명명 규칙

- **리소스 이름**: kebab-case (예: `api-server`, `web-app`)
- **변수/로컬**: snake_case (예: `container_name`, `subnet_ids`)

### 보안 기준

- **IAM 역할 분리**: Execution Role (AWS 리소스 접근) / Task Role (애플리케이션 권한) 명확히 분리
- **네트워크 격리**: Private 서브넷 배포 권장
- **시크릿 관리**: Secrets Manager/Parameter Store 사용, 코드에 하드코딩 금지
- **최소 권한**: Task Role에 필요한 최소 권한만 부여

## CPU/메모리 조합 가이드

Fargate는 특정 CPU/메모리 조합만 지원합니다:

| CPU (vCPU) | 메모리 (GB) |
|------------|-------------|
| 0.25 (256) | 0.5, 1, 2 |
| 0.5 (512) | 1, 2, 3, 4 |
| 1 (1024) | 2, 3, 4, 5, 6, 7, 8 |
| 2 (2048) | 4-16 (1GB 단위) |
| 4 (4096) | 8-30 (1GB 단위) |
| 8 (8192) | 16-60 (4GB 단위) |
| 16 (16384) | 32-120 (8GB 단위) |

**예시**:
- `cpu = 256, memory = 512` ✅
- `cpu = 512, memory = 1024` ✅
- `cpu = 1024, memory = 2048` ✅
- `cpu = 256, memory = 1024` ❌ (조합 불가)

## 운영 가이드

### ECS Exec로 컨테이너 접속

```bash
# ECS Exec 활성화 필요: enable_execute_command = true
aws ecs execute-command \
  --cluster <cluster-name> \
  --task <task-id> \
  --container <container-name> \
  --interactive \
  --command "/bin/sh"
```

### 로그 확인

```bash
# CloudWatch Logs 스트림 확인
aws logs tail "/ecs/<service-name>" --follow

# 특정 컨테이너 로그 필터링
aws logs filter-log-events \
  --log-group-name "/ecs/<service-name>" \
  --log-stream-name-prefix "<container-name>" \
  --start-time $(date -u -d '5 minutes ago' +%s)000
```

### Auto Scaling 모니터링

```bash
# Auto Scaling 활동 확인
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --resource-id service/<cluster-name>/<service-name>

# 현재 Auto Scaling 설정 확인
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --resource-ids service/<cluster-name>/<service-name>
```

### 배포 모니터링

```bash
# 서비스 배포 상태 확인
aws ecs describe-services \
  --cluster <cluster-name> \
  --services <service-name> \
  --query 'services[0].deployments'

# Task 실행 상태 확인
aws ecs list-tasks \
  --cluster <cluster-name> \
  --service-name <service-name> \
  --desired-status RUNNING
```

## 트러블슈팅

### Task가 시작되지 않음

**원인**:
- IAM 권한 부족
- ECR 이미지 pull 실패
- 서브넷/보안 그룹 설정 오류

**해결**:
```bash
# Task 실패 이유 확인
aws ecs describe-tasks \
  --cluster <cluster-name> \
  --tasks <task-arn> \
  --query 'tasks[0].stoppedReason'

# CloudWatch Logs 확인
aws logs tail "/ecs/<service-name>" --follow
```

### Auto Scaling이 작동하지 않음

**원인**:
- CloudWatch 메트릭 부족 (데이터 수집 지연)
- min_capacity = max_capacity 설정
- IAM 권한 부족

**해결**:
```bash
# Auto Scaling 정책 상태 확인
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/<cluster-name>/<service-name>

# CloudWatch 알람 상태 확인
aws cloudwatch describe-alarms \
  --alarm-name-prefix <service-name>
```

### 배포 실패 및 롤백

**원인**:
- 헬스체크 실패
- 리소스 부족
- 네트워크 연결 오류

**해결**:
```bash
# 배포 이벤트 확인
aws ecs describe-services \
  --cluster <cluster-name> \
  --services <service-name> \
  --query 'services[0].events[:10]'

# Circuit Breaker 상태 확인
aws ecs describe-services \
  --cluster <cluster-name> \
  --services <service-name> \
  --query 'services[0].deploymentConfiguration.deploymentCircuitBreaker'
```

## 요구사항

| 항목 | 버전 |
|------|------|
| Terraform | >= 1.5.0 |
| AWS Provider | >= 5.0 |

## 종속 모듈

- `common-tags`: 표준화된 리소스 태그 생성

## 라이선스

MIT

## 작성자

Platform Team

## 변경 이력

자세한 변경 이력은 [CHANGELOG.md](./CHANGELOG.md)를 참조하세요.
