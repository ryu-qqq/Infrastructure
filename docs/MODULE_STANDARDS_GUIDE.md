# Terraform Module Standards Guide

## 목적

Terraform 모듈의 코딩 표준, 네이밍 컨벤션, 파일 구조를 정의하여 일관성과 유지보수성을 확보합니다.

## 네이밍 컨벤션

### 모듈 디렉터리명
**형식**: `{service}-{resource}` 또는 `{purpose}-{function}`

**규칙**:
- 소문자 사용
- 단어 구분은 하이픈(`-`)
- AWS 서비스명 기반 권장

**예시**:
```
✅ Good
ecs-service
rds-instance
alb-target-group
common-tags
cloudwatch-log-group

❌ Bad
ECSService          # 대문자 사용
ecs_service         # 언더스코어 사용
service             # 너무 일반적
ecsServiceModule    # camelCase 사용
```

### 변수명 (variables.tf)
**형식**: `snake_case`

**규칙**:
- 소문자와 언더스코어 사용
- 명확하고 설명적인 이름
- AWS 리소스 속성명과 일치시키기 (가능한 경우)
- Boolean 변수는 `enable_`, `is_`, `has_` 접두사 사용

**예시**:
```hcl
✅ Good
variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "container_definitions" {
  description = "List of container definitions"
  type = list(object({
    name  = string
    image = string
    port  = number
  }))
}

❌ Bad
variable "vpcId" {            # camelCase
  type = string
}

variable "monitoring" {       # Boolean 의도가 불명확
  type = bool
}

variable "definitions" {      # 너무 일반적
  type = list(any)
}
```

### 출력명 (outputs.tf)
**형식**: `snake_case`

**규칙**:
- 소문자와 언더스코어 사용
- AWS 리소스 속성명과 일치
- `_id`, `_arn`, `_name` 같은 접미사 사용

**예시**:
```hcl
✅ Good
output "service_id" {
  description = "ECS service ID"
  value       = aws_ecs_service.this.id
}

output "service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.this.arn
}

output "task_definition_arn" {
  description = "Task definition ARN"
  value       = aws_ecs_task_definition.this.arn
}

❌ Bad
output "serviceID" {          # camelCase
  value = aws_ecs_service.this.id
}

output "arn" {                # 불명확 (어떤 ARN?)
  value = aws_ecs_service.this.arn
}

output "service" {            # 너무 일반적
  value = aws_ecs_service.this
}
```

### 리소스명
**형식**: `resource_type.this` 또는 `resource_type.name`

**규칙**:
- 주요 리소스는 `this` 사용
- 복수 또는 선택적 리소스는 명확한 이름 사용
- Count/for_each 사용 시 복수형 사용

**예시**:
```hcl
✅ Good
# 주요 리소스
resource "aws_ecs_service" "this" {
  name = var.name
}

# 선택적 리소스
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.enable_monitoring ? 1 : 0
}

# 복수 리소스
resource "aws_security_group_rule" "ingress" {
  for_each = var.ingress_rules
}

❌ Bad
resource "aws_ecs_service" "ecs_service" {  # 중복
  name = var.name
}

resource "aws_ecs_service" "svc" {          # 축약어
  name = var.name
}

resource "aws_ecs_service" "my_service" {   # 모호함
  name = var.name
}
```

### 로컬 변수명 (locals.tf)
**형식**: `snake_case`

**규칙**:
- 명확하고 설명적
- 용도를 반영하는 이름
- 복잡한 표현식은 로컬 변수로 추출

**예시**:
```hcl
✅ Good
locals {
  common_tags = merge(
    var.common_tags,
    {
      Name      = var.name
      ManagedBy = "Terraform"
    }
  )

  container_definitions_json = jsonencode(var.container_definitions)

  enable_service_discovery = var.service_discovery_namespace_id != null
}

❌ Bad
locals {
  tags = merge(...)                # 너무 일반적

  containerDefs = jsonencode(...)  # camelCase

  sd = var.service_discovery_namespace_id != null  # 축약어
}
```

## Variables 표준

### 변수 정의 구조
```hcl
variable "name" {
  description = "명확하고 완전한 설명"
  type        = string
  default     = null  # 선택적 변수인 경우만

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Name must contain only lowercase letters, numbers, and hyphens."
  }
}
```

### 필수 속성
1. **description**: 항상 포함, 명확하고 완전한 설명
2. **type**: 명시적으로 타입 지정
3. **validation**: 가능한 경우 포함

### 변수 타입

#### String
```hcl
variable "name" {
  description = "Resource name"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 63
    error_message = "Name must be between 1 and 63 characters."
  }
}
```

#### Number
```hcl
variable "port" {
  description = "Container port"
  type        = number
  default     = 80

  validation {
    condition     = var.port >= 1 && var.port <= 65535
    error_message = "Port must be between 1 and 65535."
  }
}
```

#### Boolean
```hcl
variable "enable_monitoring" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = false
}
```

#### List
```hcl
variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets required for high availability."
  }
}
```

#### Map
```hcl
variable "environment_variables" {
  description = "Environment variables for container"
  type        = map(string)
  default     = {}
}
```

#### Object
```hcl
variable "container_definition" {
  description = "Container definition configuration"
  type = object({
    name      = string
    image     = string
    cpu       = optional(number, 256)
    memory    = optional(number, 512)
    essential = optional(bool, true)
    port      = number
    environment = optional(list(object({
      name  = string
      value = string
    })), [])
  })

  validation {
    condition     = var.container_definition.port >= 1 && var.container_definition.port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}
```

### 변수 정렬

**우선순위**:
1. 필수 변수 (default 없음)
2. 선택적 변수 (default 있음)
3. 각 그룹 내에서 알파벳 순

**예시**:
```hcl
# --- 필수 변수 (알파벳 순) ---
variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "name" {
  description = "Service name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

# --- 선택적 변수 (알파벳 순) ---
variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "enable_autoscaling" {
  description = "Enable auto scaling"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
```

### Validation 패턴

#### 네이밍 규칙 검증
```hcl
variable "name" {
  description = "Resource name"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Name must contain only lowercase letters, numbers, and hyphens."
  }
}
```

#### 범위 검증
```hcl
variable "desired_count" {
  description = "Desired task count"
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 0 && var.desired_count <= 100
    error_message = "Desired count must be between 0 and 100."
  }
}
```

#### 리스트 검증
```hcl
variable "subnet_ids" {
  description = "Subnet IDs"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets required."
  }

  validation {
    condition     = alltrue([for id in var.subnet_ids : can(regex("^subnet-", id))])
    error_message = "All subnet IDs must start with 'subnet-'."
  }
}
```

#### Enum 검증
```hcl
variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "info"

  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}
```

## Outputs 표준

### 출력 정의 구조
```hcl
output "resource_id" {
  description = "명확하고 완전한 설명"
  value       = aws_resource.this.id
  sensitive   = false  # 민감한 정보인 경우 true
}
```

### 출력 정렬

**우선순위**:
1. 주요 식별자 (ID, ARN, Name)
2. 기타 출력
3. 알파벳 순

**예시**:
```hcl
# --- 주요 식별자 ---
output "service_id" {
  description = "ECS service ID"
  value       = aws_ecs_service.this.id
}

output "service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.this.arn
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

# --- 기타 출력 (알파벳 순) ---
output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.this.id
}

output "task_definition_arn" {
  description = "Task definition ARN"
  value       = aws_ecs_task_definition.this.arn
}

output "task_role_arn" {
  description = "Task IAM role ARN"
  value       = aws_iam_role.task.arn
  sensitive   = false
}
```

### 민감한 출력
```hcl
output "database_password" {
  description = "Database password (sensitive)"
  value       = random_password.db.result
  sensitive   = true
}

output "api_key" {
  description = "API key for external integration"
  value       = aws_secretsmanager_secret_version.api_key.secret_string
  sensitive   = true
}
```

## 파일 구조 표준

### main.tf
```hcl
# Module: {module-name}
# Description: {간단한 설명}

# --- Locals ---
locals {
  common_tags = merge(
    var.common_tags,
    {
      Name      = var.name
      ManagedBy = "Terraform"
    }
  )
}

# --- Main Resources ---
resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  tags = local.common_tags
}

# --- Supporting Resources ---
resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-sg"
    }
  )
}
```

### versions.tf
```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}
```

### locals.tf (선택적)
```hcl
# Local values for module logic

locals {
  # Common tags applied to all resources
  common_tags = merge(
    var.common_tags,
    {
      Name      = var.name
      Module    = "ecs-service"
      ManagedBy = "Terraform"
    }
  )

  # Container definitions JSON
  container_definitions_json = jsonencode(var.container_definitions)

  # Computed values
  enable_service_discovery = var.service_discovery_namespace_id != null
  enable_load_balancer     = var.target_group_arn != null
}
```

## 코딩 스타일

### 들여쓰기
- **2 spaces** 사용 (탭 사용 금지)
- 중첩된 블록은 일관되게 들여쓰기

### 블록 구분
```hcl
resource "aws_ecs_service" "this" {
  name    = var.name
  cluster = var.cluster_id

  # 관련 속성을 빈 줄로 그룹화
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [aws_security_group.this.id]
  }

  # 태그는 마지막에
  tags = local.common_tags
}
```

### 정렬
```hcl
# 속성은 논리적 그룹별로, 그룹 내에서는 알파벳 순
resource "aws_ecs_service" "this" {
  # 식별자
  cluster = var.cluster_id
  name    = var.name

  # 구성
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.this.arn

  # 네트워크
  network_configuration {
    security_groups  = [aws_security_group.this.id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }

  # 태그
  tags = local.common_tags
}
```

### 주석
```hcl
# 블록 수준 주석: 리소스나 로직 그룹 설명
resource "aws_ecs_service" "this" {
  name = var.name

  # Enable circuit breaker to prevent bad deployments
  deployment_circuit_breaker {
    enable   = var.enable_circuit_breaker
    rollback = true
  }
}

# 복잡한 표현식 설명
locals {
  # Merge user-provided tags with standard tags
  # Standard tags include Name, Module, and ManagedBy
  final_tags = merge(
    var.common_tags,
    {
      Name      = var.name
      Module    = "ecs-service"
      ManagedBy = "Terraform"
    }
  )
}
```

### 줄 길이
- 최대 120자 권장
- 긴 리스트나 객체는 여러 줄로 분리

```hcl
✅ Good
variable "container_definitions" {
  description = "List of container definitions for the task"
  type = list(object({
    name      = string
    image     = string
    cpu       = number
    memory    = number
    essential = bool
  }))
}

❌ Bad (너무 긴 한 줄)
variable "container_definitions" { description = "List of container definitions for the task" type = list(object({ name = string image = string cpu = number memory = number essential = bool })) }
```

## 문서화 표준

### 파일 헤더 주석
```hcl
# Module: ecs-service
# Purpose: Creates and manages an ECS Fargate service with optional auto scaling
# Version: 1.0.0
# Maintainer: Infrastructure Team
```

### 복잡한 로직 주석
```hcl
# Calculate the number of container instances needed based on
# desired task count and tasks per instance
locals {
  # Each instance can run up to 10 tasks
  # Add 1 for ceiling division
  required_instances = floor((var.desired_count / 10) + 1)
}
```

### TODO 주석 (사용 제한)
```hcl
# TODO는 개발 중에만 사용, 릴리스 전 제거
# TODO(IN-XXX): Add support for spot instances
```

## 테스트 및 검증

### Terraform Format
```bash
terraform fmt -recursive
```

### Terraform Validate
```bash
terraform init
terraform validate
```

### Terraform Plan (예제)
```bash
cd examples/basic
terraform init
terraform plan
```

## 체크리스트

### 코딩 표준
- [ ] Snake_case 네이밍 일관성
- [ ] 변수/출력 알파벳 순 정렬
- [ ] Validation 블록 포함
- [ ] Description 명확하게 작성
- [ ] 2 spaces 들여쓰기
- [ ] terraform fmt 통과

### 문서화
- [ ] 파일 헤더 주석
- [ ] 복잡한 로직 주석
- [ ] README.md 완성

### 테스트
- [ ] terraform validate 통과
- [ ] 예제 terraform plan 통과

## 관련 문서

- [모듈 디렉터리 구조](./MODULES_DIRECTORY_STRUCTURE.md)
- [모듈 README 템플릿](./MODULE_TEMPLATE.md)
- [Terraform Style Guide](https://www.terraform.io/docs/language/syntax/style.html)

## Epic & Task

- **Epic**: [IN-100 - 재사용 가능한 표준 모듈](https://ryuqqq.atlassian.net/browse/IN-100)
- **Task**: [IN-121 - 모듈 디렉터리 구조 설계](https://ryuqqq.atlassian.net/browse/IN-121)
