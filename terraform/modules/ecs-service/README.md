# ECS Service Terraform Module

AWS ECS Fargate 서비스를 배포하고 관리하기 위한 재사용 가능한 Terraform 모듈입니다. Task Definition, Service, Auto Scaling, 로깅을 포함한 완전한 ECS 서비스 스택을 제공합니다.

## Features

- ✅ ECS Fargate Task Definition 자동 생성
- ✅ ECS Service 배포 및 관리
- ✅ 환경 변수 및 Secrets Manager 통합
- ✅ 컨테이너 헬스체크 설정
- ✅ Application Load Balancer 통합 (선택적)
- ✅ Auto Scaling (CPU 및 메모리 기반)
- ✅ CloudWatch Logs 자동 구성
- ✅ Deployment Circuit Breaker (자동 롤백)
- ✅ ECS Exec 지원 (컨테이너 디버깅)
- ✅ 표준화된 태그 자동 적용 (common-tags 모듈 통합)
- ✅ 포괄적인 변수 검증

## Usage

### Basic Example

```hcl
# 공통 태그 모듈 (모든 모듈에서 권장)
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "api-server"
  team        = "platform-team"
  owner       = "fbtkdals2@naver.com"
  cost_center = "engineering"
}

# ECS 클러스터 (이미 존재하는 경우 data source 사용)
resource "aws_ecs_cluster" "main" {
  name = "my-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# IAM 역할 (Task Execution Role)
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM 역할 (Task Role)
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# 기본 ECS Service 생성
module "ecs_service" {
  source = "../../modules/ecs-service"

  # 필수 변수
  name               = "my-api-service"
  cluster_id         = aws_ecs_cluster.main.id
  container_name     = "api"
  container_image    = "nginx:latest"
  container_port     = 80
  cpu                = 256
  memory             = 512
  desired_count      = 1
  subnet_ids         = ["subnet-xxx", "subnet-yyy"]
  security_group_ids = ["sg-xxx"]
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  # 공통 태그 적용
  common_tags = module.common_tags.tags
}
```

### Advanced Example with Health Check and Environment Variables

```hcl
module "ecs_service" {
  source = "../../modules/ecs-service"

  # 기본 설정
  name               = "my-api-service"
  cluster_id         = aws_ecs_cluster.main.id
  container_name     = "api"
  container_image    = "my-ecr-repo/api:v1.0.0"
  container_port     = 8080
  cpu                = 512
  memory             = 1024
  desired_count      = 2
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.ecs_tasks.id]
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  # 환경 변수
  container_environment = [
    {
      name  = "APP_ENV"
      value = "production"
    },
    {
      name  = "LOG_LEVEL"
      value = "info"
    }
  ]

  # Secrets Manager 통합
  container_secrets = [
    {
      name      = "DB_PASSWORD"
      valueFrom = aws_secretsmanager_secret.db_password.arn
    },
    {
      name      = "API_KEY"
      valueFrom = aws_secretsmanager_secret.api_key.arn
    }
  ]

  # 헬스체크 설정
  health_check_command = [
    "CMD-SHELL",
    "curl -f http://localhost:8080/health || exit 1"
  ]
  health_check_interval    = 30
  health_check_timeout     = 5
  health_check_retries     = 3
  health_check_start_period = 60

  # 로드 밸런서 연결
  load_balancer_config = {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8080
  }
  health_check_grace_period_seconds = 60

  # Auto Scaling 활성화
  enable_autoscaling        = true
  autoscaling_min_capacity  = 2
  autoscaling_max_capacity  = 10
  autoscaling_target_cpu    = 70
  autoscaling_target_memory = 80

  # ECS Exec 활성화 (디버깅용)
  enable_execute_command = true

  # 공통 태그
  common_tags = module.common_tags.tags
}
```

### Complete Example

전체 기능을 활용한 실제 운영 시나리오는 [examples/complete](./examples/complete/) 디렉터리를 참조하세요.

## Inputs

### Required Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `cluster_id` | ECS 클러스터 ID | `string` | - | yes |
| `common_tags` | common-tags 모듈에서 생성된 표준 태그 | `map(string)` | - | yes |
| `container_image` | 컨테이너 이미지 (예: 'nginx:latest' 또는 ECR URL) | `string` | - | yes |
| `container_name` | 컨테이너 이름 | `string` | - | yes |
| `container_port` | 컨테이너가 수신하는 포트 | `number` | - | yes |
| `cpu` | CPU 유닛 (256, 512, 1024, 2048, 4096) | `number` | - | yes |
| `execution_role_arn` | ECS Task Execution Role ARN | `string` | - | yes |
| `memory` | 메모리 (MiB) | `number` | - | yes |
| `name` | ECS 서비스 이름 | `string` | - | yes |
| `security_group_ids` | ECS 태스크에 연결할 보안 그룹 ID 목록 | `list(string)` | - | yes |
| `subnet_ids` | ECS 태스크가 배포될 서브넷 ID 목록 | `list(string)` | - | yes |
| `task_role_arn` | ECS Task Role ARN | `string` | - | yes |

### Optional Variables - Container Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `container_environment` | 컨테이너에 전달할 환경 변수 | `list(object)` | `[]` | no |
| `container_secrets` | Secrets Manager 또는 Parameter Store의 시크릿 | `list(object)` | `[]` | no |
| `desired_count` | 실행할 태스크 수 | `number` | `1` | no |
| `enable_container_insights` | Container Insights 활성화 | `bool` | `true` | no |
| `enable_execute_command` | ECS Exec 활성화 (SSH-like access) | `bool` | `false` | no |
| `health_check_command` | 컨테이너 헬스체크 명령 | `list(string)` | `null` | no |
| `health_check_interval` | 헬스체크 간격 (초, 5-300) | `number` | `30` | no |
| `health_check_retries` | 헬스체크 실패 재시도 횟수 (1-10) | `number` | `3` | no |
| `health_check_start_period` | 헬스체크 시작 대기 시간 (초, 0-300) | `number` | `60` | no |
| `health_check_timeout` | 헬스체크 타임아웃 (초, 2-60) | `number` | `5` | no |

### Optional Variables - Service Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `assign_public_ip` | 퍼블릭 IP 할당 여부 | `bool` | `false` | no |
| `deployment_circuit_breaker_enable` | Deployment Circuit Breaker 활성화 | `bool` | `true` | no |
| `deployment_circuit_breaker_rollback` | 배포 실패 시 자동 롤백 | `bool` | `true` | no |
| `deployment_maximum_percent` | 배포 중 최대 태스크 비율 (100-200) | `number` | `200` | no |
| `deployment_minimum_healthy_percent` | 배포 중 최소 정상 태스크 비율 (0-100) | `number` | `100` | no |
| `enable_ecs_managed_tags` | ECS 관리 태그 활성화 | `bool` | `true` | no |
| `health_check_grace_period_seconds` | ALB 헬스체크 대기 시간 (초) | `number` | `null` | no |
| `load_balancer_config` | 로드 밸런서 설정 (없으면 null) | `object` | `null` | no |
| `propagate_tags` | 태그 전파 설정 (TASK_DEFINITION, SERVICE, NONE) | `string` | `"SERVICE"` | no |

### Optional Variables - Auto Scaling

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `enable_autoscaling` | Auto Scaling 활성화 | `bool` | `false` | no |
| `autoscaling_max_capacity` | 최대 태스크 수 | `number` | `4` | no |
| `autoscaling_min_capacity` | 최소 태스크 수 | `number` | `1` | no |
| `autoscaling_target_cpu` | CPU 목표 사용률 (1-100) | `number` | `70` | no |
| `autoscaling_target_memory` | 메모리 목표 사용률 (1-100) | `number` | `80` | no |

### Optional Variables - Logging

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `log_configuration` | 로그 설정 (null이면 기본 CloudWatch Logs 사용) | `object` | `null` | no |
| `log_retention_days` | CloudWatch Logs 보존 기간 (일) | `number` | `7` | no |

## Outputs

### Primary Identifiers

| Name | Description |
|------|-------------|
| `service_id` | ECS Service ID |
| `service_name` | ECS Service 이름 |
| `task_definition_arn` | ECS Task Definition의 전체 ARN |

### Additional Outputs (Alphabetical)

| Name | Description |
|------|-------------|
| `autoscaling_cpu_policy_arn` | CPU Auto Scaling Policy ARN |
| `autoscaling_memory_policy_arn` | Memory Auto Scaling Policy ARN |
| `autoscaling_target_id` | Auto Scaling Target ID |
| `cloudwatch_log_group_arn` | CloudWatch Log Group ARN |
| `cloudwatch_log_group_name` | CloudWatch Log Group 이름 |
| `container_name` | 컨테이너 이름 |
| `container_port` | 컨테이너 포트 |
| `service_cluster` | ECS Service가 실행 중인 클러스터 |
| `service_desired_count` | Service의 Desired Count |
| `task_definition_family` | ECS Task Definition Family |
| `task_definition_revision` | ECS Task Definition Revision 번호 |

## Resource Types

이 모듈은 다음 AWS 리소스를 생성합니다:

- `aws_ecs_task_definition.this` - ECS Task Definition
- `aws_ecs_service.this` - ECS Service
- `aws_cloudwatch_log_group.this` - CloudWatch Log Group (log_configuration이 null인 경우)
- `aws_appautoscaling_target.this` - Auto Scaling Target (enable_autoscaling이 true인 경우)
- `aws_appautoscaling_policy.cpu` - CPU 기반 Auto Scaling Policy
- `aws_appautoscaling_policy.memory` - Memory 기반 Auto Scaling Policy

## Validation Rules

모듈은 다음 항목을 자동으로 검증합니다:

- ✅ 컨테이너 이름 네이밍 규칙 (소문자, 숫자, 하이픈만)
- ✅ 컨테이너 포트 범위 (1-65535)
- ✅ CPU 값 (256, 512, 1024, 2048, 4096만 허용)
- ✅ 메모리 값 (0보다 큰 값)
- ✅ 헬스체크 파라미터 범위
- ✅ 배포 설정 범위
- ✅ Auto Scaling 파라미터 범위
- ✅ CloudWatch Logs 보존 기간 값

유효하지 않은 입력은 `terraform plan` 단계에서 명확한 에러 메시지와 함께 실패합니다.

## Tags Applied

모든 리소스는 자동으로 다음 태그를 받습니다:

**common-tags 모듈로부터:**
- `Environment` - 환경 (dev, staging, prod)
- `Service` - 서비스 이름
- `Team` - 담당 팀
- `Owner` - 소유자 이메일
- `CostCenter` - 비용 센터
- `ManagedBy` - "Terraform"
- `Project` - 프로젝트 이름

**모듈별 태그:**
- `Name` - 리소스 이름
- `Description` - 리소스 설명

## Examples Directory

추가 사용 예제는 [examples/](./examples/) 디렉터리를 참조하세요:

- [basic/](./examples/basic/) - 최소 설정 예제
- [advanced/](./examples/advanced/) - 고급 기능 활용 예제
- [complete/](./examples/complete/) - 모든 기능을 활용한 실제 운영 시나리오

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## CPU and Memory Combinations

Fargate는 특정 CPU/메모리 조합만 지원합니다:

| CPU | Memory (MiB) |
|-----|--------------|
| 256 | 512, 1024, 2048 |
| 512 | 1024, 2048, 3072, 4096 |
| 1024 | 2048, 3072, 4096, 5120, 6144, 7168, 8192 |
| 2048 | 4096-16384 (1024 단위) |
| 4096 | 8192-30720 (1024 단위) |

## Related Documentation

- [모듈 디렉터리 구조](../../../docs/MODULES_DIRECTORY_STRUCTURE.md)
- [태그 표준](../../../docs/TAGGING_STANDARDS.md)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS Fargate Documentation](https://docs.aws.amazon.com/fargate/)

## Changelog

변경 이력은 [CHANGELOG.md](./CHANGELOG.md)를 참조하세요.

## Epic & Tasks


## License

Internal use only - Infrastructure Team

---

## Advanced Configuration

### Blue/Green Deployment Strategy

단일 태스크로 EFS를 사용하는 경우 (예: Atlantis):

```hcl
module "ecs_service" {
  source = "../../modules/ecs-service"
  # ...

  deployment_maximum_percent         = 100  # 동시에 1개 태스크만
  deployment_minimum_healthy_percent = 0    # 새 태스크 시작 전 기존 태스크 중지
}
```

### ECS Exec 활성화

디버깅을 위한 SSH-like 액세스:

```hcl
module "ecs_service" {
  source = "../../modules/ecs-service"
  # ...

  enable_execute_command = true
}

# 사용 방법:
# aws ecs execute-command \
#   --cluster my-cluster \
#   --task task-id \
#   --container my-container \
#   --interactive \
#   --command "/bin/sh"
```

### Custom Log Configuration

CloudWatch Logs 외 다른 로그 드라이버 사용:

```hcl
module "ecs_service" {
  source = "../../modules/ecs-service"
  # ...

  log_configuration = {
    log_driver = "awsfirelens"
    options = {
      "Name"   = "cloudwatch"
      "region" = "ap-northeast-2"
    }
  }
}
```

## Troubleshooting

### 태스크가 시작되지 않음

**증상**: ECS 태스크가 PENDING 상태에서 멈춤

**해결**:
1. Task Execution Role에 필요한 권한 확인
2. 서브넷에 NAT Gateway 또는 VPC 엔드포인트 확인
3. 보안 그룹 아웃바운드 규칙 확인
4. ECR 이미지 접근 권한 확인

### 헬스체크 실패

**증상**: 태스크가 반복적으로 재시작됨

**해결**:
1. `health_check_start_period` 증가 (애플리케이션 시작 시간 고려)
2. 헬스체크 엔드포인트가 올바르게 응답하는지 확인
3. 컨테이너 로그에서 에러 메시지 확인

### Auto Scaling 작동하지 않음

**증상**: CPU/메모리가 높아도 스케일 아웃되지 않음

**해결**:
1. CloudWatch 메트릭 확인
2. Auto Scaling 정책 이벤트 히스토리 확인
3. `autoscaling_max_capacity` 값 확인

## Security Considerations

- 프라이빗 서브넷에 태스크 배포 권장
- 최소 권한 원칙으로 IAM 역할 구성
- Secrets Manager 사용하여 민감 정보 관리
- 보안 그룹 규칙 최소화
- Container Insights 활성화하여 모니터링 강화

## Performance Considerations

- CPU/메모리 크기 적절히 선택
- Auto Scaling으로 부하 대응
- CloudWatch Logs 보존 기간 최적화
- 불필요한 환경 변수 최소화

## Cost Optimization

- 적절한 CPU/메모리 조합 선택 (오버프로비저닝 방지)
- Auto Scaling Min Capacity 최소화
- CloudWatch Logs 보존 기간 단축
- Spot Fargate 고려 (개발/테스트 환경)
