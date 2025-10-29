# Terraform Module Examples Guide

## 목적

모듈 사용 예제의 구조와 작성 가이드를 정의합니다. 예제는 사용자가 모듈을 빠르게 이해하고 적용할 수 있도록 돕습니다.

## 예제 디렉터리 구조

```
terraform/modules/{module-name}/
└── examples/
    ├── README.md              # 예제 목록 및 개요
    ├── basic/                 # 기본 사용 예제
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars.example
    │   └── README.md
    ├── advanced/              # 고급 기능 예제
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars.example
    │   └── README.md
    └── complete/              # 완전한 운영 시나리오
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── terraform.tfvars.example
        └── README.md
```

## 예제 카테고리

### 1. Basic Example (필수)
**목적**: 최소한의 설정으로 모듈을 사용하는 방법

**특징**:
- 필수 변수만 사용
- 기본값에 의존
- 간단하고 명확한 구성
- 초보자가 이해하기 쉬운 코드

**예시 (ECS Service):**
```hcl
# examples/basic/main.tf
module "ecs_service" {
  source = "../../"

  name           = "api-server"
  cluster_id     = "arn:aws:ecs:ap-northeast-2:123456789012:cluster/main"
  vpc_id         = "vpc-xxxxx"
  subnet_ids     = ["subnet-xxxxx", "subnet-yyyyy"]

  container_definitions = [{
    name  = "app"
    image = "nginx:latest"
    port  = 80
  }]

  common_tags = {
    Environment = "dev"
    Service     = "api-server"
  }
}
```

### 2. Advanced Example (권장)
**목적**: 주요 선택적 기능을 활용하는 방법

**특징**:
- 선택적 변수 일부 활용
- 실제 운영에 가까운 구성
- Auto scaling, 모니터링 등 고급 기능 포함
- 중급 사용자 대상

**예시 (ECS Service):**
```hcl
# examples/advanced/main.tf
module "ecs_service" {
  source = "../../"

  name       = "api-server"
  cluster_id = "arn:aws:ecs:ap-northeast-2:123456789012:cluster/main"
  vpc_id     = "vpc-xxxxx"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

  container_definitions = [{
    name  = "app"
    image = "myapp:1.0.0"
    port  = 8080
    environment = [
      { name = "ENV", value = "production" }
    ]
  }]

  # Auto Scaling
  enable_autoscaling = true
  min_capacity       = 2
  max_capacity       = 10
  cpu_threshold      = 70
  memory_threshold   = 80

  # Load Balancer
  target_group_arn         = aws_lb_target_group.app.arn
  health_check_grace_period = 60

  # Monitoring
  enable_container_insights = true
  enable_execute_command    = true

  common_tags = module.common_tags.tags
}

module "common_tags" {
  source = "../../../common-tags"

  environment = "prod"
  service     = "api-server"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}
```

### 3. Complete Example (권장)
**목적**: 모든 기능을 활용한 실제 운영 시나리오

**특징**:
- 모든 주요 변수 활용
- 다중 모듈 통합
- 실제 프로덕션 환경 반영
- 고급 사용자 및 참고용

**예시 (ECS Service):**
```hcl
# examples/complete/main.tf
# VPC 및 네트워크 (가정)
data "aws_vpc" "main" {
  tags = { Name = "main-vpc" }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  tags = { Tier = "private" }
}

# ECS Cluster (가정)
data "aws_ecs_cluster" "main" {
  cluster_name = "production"
}

# ALB Target Group
resource "aws_lb_target_group" "app" {
  name     = "api-server-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# CloudWatch Log Group
module "logs" {
  source = "../../../cloudwatch-log-group"

  name              = "/aws/ecs/api-server"
  retention_in_days = 30
  kms_key_id        = data.aws_kms_key.logs.arn
  log_type          = "application"
  common_tags       = module.common_tags.tags
}

# Common Tags
module "common_tags" {
  source = "../../../common-tags"

  environment = "prod"
  service     = "api-server"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}

# ECS Service with Full Configuration
module "ecs_service" {
  source = "../../"

  # Basic Configuration
  name       = "api-server"
  cluster_id = data.aws_ecs_cluster.main.id
  vpc_id     = data.aws_vpc.main.id
  subnet_ids = data.aws_subnets.private.ids

  # Container Definitions
  container_definitions = [{
    name      = "app"
    image     = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/api-server:1.2.3"
    cpu       = 512
    memory    = 1024
    essential = true
    port      = 8080

    environment = [
      { name = "ENV", value = "production" },
      { name = "LOG_LEVEL", value = "info" }
    ]

    secrets = [
      {
        name      = "DATABASE_URL"
        valueFrom = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:db-url"
      }
    ]

    log_configuration = {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = module.logs.log_group_name
        "awslogs-region"        = "ap-northeast-2"
        "awslogs-stream-prefix" = "app"
      }
    }
  }]

  # Task Configuration
  task_cpu    = 512
  task_memory = 1024
  task_role_arn      = aws_iam_role.task.arn
  execution_role_arn = aws_iam_role.execution.arn

  # Service Configuration
  desired_count                     = 3
  deployment_maximum_percent        = 200
  deployment_minimum_healthy_percent = 100
  enable_circuit_breaker            = true
  health_check_grace_period         = 60

  # Load Balancer
  target_group_arn = aws_lb_target_group.app.arn
  container_name   = "app"
  container_port   = 8080

  # Auto Scaling
  enable_autoscaling = true
  min_capacity       = 3
  max_capacity       = 20

  cpu_target_value    = 70
  memory_target_value = 80

  scale_in_cooldown  = 300
  scale_out_cooldown = 60

  # Service Discovery
  enable_service_discovery = true
  service_discovery_namespace_id = data.aws_service_discovery_private_dns_namespace.main.id

  # Monitoring & Observability
  enable_container_insights = true
  enable_execute_command    = true

  # Security
  security_group_ids = [aws_security_group.ecs_service.id]

  # Tags
  common_tags = module.common_tags.tags
}

# Outputs
output "service_name" {
  value = module.ecs_service.service_name
}

output "task_definition_arn" {
  value = module.ecs_service.task_definition_arn
}
```

## 예제별 README.md 구조

### examples/README.md (전체 개요)
```markdown
# {Module Name} Examples

이 디렉터리는 {module-name} 모듈의 다양한 사용 예제를 포함합니다.

## 예제 목록

### [Basic Example](./basic/)
최소한의 설정으로 모듈을 사용하는 기본 예제입니다.
- 필수 변수만 사용
- 기본값에 의존
- 초보자 권장

### [Advanced Example](./advanced/)
주요 선택적 기능을 활용하는 고급 예제입니다.
- Auto scaling 설정
- 모니터링 통합
- Load balancer 연동

### [Complete Example](./complete/)
모든 기능을 활용한 실제 운영 시나리오 예제입니다.
- 전체 기능 활용
- 다중 모듈 통합
- 프로덕션 환경 반영

## 사용 방법

1. 원하는 예제 디렉터리로 이동
2. `terraform.tfvars.example`을 `terraform.tfvars`로 복사
3. 변수 값을 환경에 맞게 수정
4. Terraform 실행

```bash
cd basic/
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 수정
terraform init
terraform plan
terraform apply
```

## 주의사항

- 예제를 실제 환경에 적용하기 전에 변수 값을 검토하세요
- 예제는 독립적으로 실행 가능하도록 설계되었습니다
- 프로덕션 환경에서는 Complete Example을 참고하세요
```

### examples/{type}/README.md (개별 예제)
```markdown
# {Type} Example

## 설명

{이 예제의 목적과 특징}

## 사용하는 기능

- ✅ {기능 1}
- ✅ {기능 2}
- ✅ {기능 3}

## 사전 요구사항

- AWS Account
- Terraform >= 1.5.0
- {기타 요구사항}

## 사용 방법

1. 변수 설정
```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집
```

2. Terraform 실행
```bash
terraform init
terraform plan
terraform apply
```

3. 리소스 정리
```bash
terraform destroy
```

## 주요 설정

### {설정 1}
{설명}

### {설정 2}
{설명}

## 예상 비용

{대략적인 월간 비용 추정}

## 출력 값

예제 실행 후 다음 값들이 출력됩니다:
- `{output_name}`: {설명}

## 참고 문서

- [모듈 README](../../README.md)
- {관련 문서 링크}
```

## 파일별 가이드

### main.tf
```hcl
# Provider 설정 (예제 실행에 필요)
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 모듈 호출
module "example" {
  source = "../../"  # 상대 경로로 모듈 참조

  # 변수 설정
  name = var.name
  # ...
}

# 필요한 Data Source (예: VPC, Subnet 조회)
data "aws_vpc" "main" {
  tags = {
    Name = var.vpc_name
  }
}

# 필요한 리소스 (예: Security Group, IAM Role)
resource "aws_security_group" "example" {
  # ...
}
```

### variables.tf
```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "name" {
  description = "Resource name"
  type        = string
}

# 예제 실행에 필요한 변수들
variable "vpc_name" {
  description = "VPC name to use"
  type        = string
}
```

### outputs.tf
```hcl
output "resource_id" {
  description = "Created resource ID"
  value       = module.example.id
}

output "resource_arn" {
  description = "Created resource ARN"
  value       = module.example.arn
}

# 유용한 출력 값들
```

### terraform.tfvars.example
```hcl
# Copy this file to terraform.tfvars and adjust values

aws_region = "ap-northeast-2"
name       = "my-example"
vpc_name   = "main-vpc"

# Adjust these values for your environment
# cluster_id = "arn:aws:ecs:ap-northeast-2:123456789012:cluster/main"
```

## 예제 작성 체크리스트

### 모든 예제 공통
- [ ] README.md 작성 완료
- [ ] terraform.tfvars.example 제공
- [ ] terraform init 정상 실행
- [ ] terraform plan 정상 실행 (실제 리소스 없어도 plan은 통과)
- [ ] 변수 설명 명확
- [ ] 출력 값 포함
- [ ] 주석으로 설명 추가

### Basic Example
- [ ] 필수 변수만 사용
- [ ] 최소 10줄 이내의 모듈 호출 블록
- [ ] 초보자가 이해 가능한 간단한 구조

### Advanced Example
- [ ] 주요 선택적 기능 2-3개 포함
- [ ] 실제 운영에 가까운 구성
- [ ] common-tags 모듈 통합

### Complete Example
- [ ] 모든 주요 기능 포함
- [ ] 다른 모듈과의 통합
- [ ] IAM, Security Group 등 관련 리소스 포함
- [ ] 프로덕션 수준의 설정

## 테스트 가이드

### 예제 검증 (로컬)
```bash
# 각 예제 디렉터리에서
terraform fmt -check
terraform init
terraform validate
terraform plan
```

### 자동화된 테스트 (향후)
```bash
# Terratest를 사용한 예제 테스트
go test -v ./tests/
```

## 관련 문서

- [모듈 디렉터리 구조](./MODULES_DIRECTORY_STRUCTURE.md)
- [모듈 README 템플릿](./MODULE_TEMPLATE.md)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## Epic & Task

