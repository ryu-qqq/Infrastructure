# Security Group Module

재사용 가능한 AWS Security Group 관리 모듈입니다. ALB, ECS, RDS, VPC Endpoint 등의 일반적인 사용 사례에 대한 사전 구성된 규칙과 함께 완전히 커스터마이즈 가능한 보안 그룹을 생성할 수 있습니다.

## Features

- **ALB Security Group**: HTTP/HTTPS 인바운드 트래픽 허용
- **ECS Security Group**: ALB 또는 다른 소스로부터의 컨테이너 트래픽 허용
- **RDS Security Group**: ECS 또는 다른 소스로부터의 데이터베이스 트래픽 허용
- **VPC Endpoint Security Group**: VPC 엔드포인트 접근 제어
- **Custom Rules**: 완전히 커스터마이즈 가능한 인그레스/이그레스 규칙
- **Security Group References**: 보안 그룹 간 참조를 통한 안전한 트래픽 제어
- **Flexible Configuration**: CIDR 블록 및 보안 그룹 ID 조합 지원

## Usage

### ALB Security Group

```hcl
module "alb_sg" {
  source = "../../modules/security-group"

  name        = "my-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = "vpc-12345678"
  type        = "alb"

  # ALB 구성
  alb_enable_http  = true
  alb_enable_https = true
  alb_ingress_cidr_blocks = ["0.0.0.0/0"]

  common_tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

### ECS Security Group

```hcl
module "ecs_sg" {
  source = "../../modules/security-group"

  name        = "my-ecs-sg"
  description = "Security group for ECS service"
  vpc_id      = "vpc-12345678"
  type        = "ecs"

  # ECS 구성
  ecs_ingress_from_alb_sg_id = module.alb_sg.security_group_id
  ecs_container_port         = 8080

  # 추가 소스 허용 (선택사항)
  ecs_additional_ingress_sg_ids = []

  common_tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

### RDS Security Group

```hcl
module "rds_sg" {
  source = "../../modules/security-group"

  name        = "my-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = "vpc-12345678"
  type        = "rds"

  # RDS 구성
  rds_ingress_from_ecs_sg_id = module.ecs_sg.security_group_id
  rds_port                   = 5432

  # CIDR 블록에서의 접근 허용 (주의: 필요한 경우에만 사용)
  rds_ingress_cidr_blocks = []

  common_tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

### VPC Endpoint Security Group

```hcl
module "vpc_endpoint_sg" {
  source = "../../modules/security-group"

  name        = "my-vpc-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = "vpc-12345678"
  type        = "vpc-endpoint"

  # VPC Endpoint 구성
  vpc_endpoint_port                = 443
  vpc_endpoint_ingress_sg_ids      = [module.ecs_sg.security_group_id]
  vpc_endpoint_ingress_cidr_blocks = []

  common_tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

### Custom Security Group with Custom Rules

```hcl
module "custom_sg" {
  source = "../../modules/security-group"

  name        = "my-custom-sg"
  description = "Custom security group with specific rules"
  vpc_id      = "vpc-12345678"
  type        = "custom"

  # 커스텀 인그레스 규칙
  custom_ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "Allow SSH from VPC"
    },
    {
      from_port                = 3306
      to_port                  = 3306
      protocol                 = "tcp"
      source_security_group_id = "sg-12345678"
      description              = "Allow MySQL from application security group"
    }
  ]

  # 커스텀 이그레스 규칙
  custom_egress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS outbound"
    }
  ]

  # 기본 이그레스 규칙 비활성화 (커스텀 규칙만 사용)
  enable_default_egress = false

  common_tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

### Complete Application Stack

```hcl
# ALB Security Group
module "alb_sg" {
  source = "../../modules/security-group"

  name   = "my-app-alb-sg"
  vpc_id = var.vpc_id
  type   = "alb"

  alb_enable_http         = true
  alb_enable_https        = true
  alb_ingress_cidr_blocks = ["0.0.0.0/0"]

  common_tags = var.common_tags
}

# ECS Security Group
module "ecs_sg" {
  source = "../../modules/security-group"

  name   = "my-app-ecs-sg"
  vpc_id = var.vpc_id
  type   = "ecs"

  ecs_ingress_from_alb_sg_id = module.alb_sg.security_group_id
  ecs_container_port         = 8080

  common_tags = var.common_tags
}

# RDS Security Group
module "rds_sg" {
  source = "../../modules/security-group"

  name   = "my-app-rds-sg"
  vpc_id = var.vpc_id
  type   = "rds"

  rds_ingress_from_ecs_sg_id = module.ecs_sg.security_group_id
  rds_port                   = 5432

  common_tags = var.common_tags
}

# ALB 리소스
module "alb" {
  source = "../../modules/alb"

  name               = "my-app-alb"
  security_group_ids = [module.alb_sg.security_group_id]
  # ... 나머지 ALB 구성
}

# ECS Service
module "ecs_service" {
  source = "../../modules/ecs-service"

  name               = "my-app-service"
  security_group_ids = [module.ecs_sg.security_group_id]
  # ... 나머지 ECS 구성
}

# RDS Instance
module "rds" {
  source = "../../modules/rds"

  identifier         = "my-app-db"
  security_group_ids = [module.rds_sg.security_group_id]
  # ... 나머지 RDS 구성
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Inputs

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| name | Name of the security group | `string` |
| vpc_id | VPC ID where the security group will be created | `string` |

### Optional Variables - General Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| description | Description of the security group | `string` | `"Managed by Terraform"` |
| common_tags | Common tags to apply to all resources | `map(string)` | `{}` |
| type | Type of security group (alb, ecs, rds, vpc-endpoint, custom) | `string` | `"custom"` |
| revoke_rules_on_delete | Revoke all rules before deleting the group | `bool` | `false` |

### Optional Variables - ALB Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| alb_ingress_cidr_blocks | CIDR blocks allowed to access ALB | `list(string)` | `["0.0.0.0/0"]` |
| alb_http_port | HTTP port for ALB | `number` | `80` |
| alb_https_port | HTTPS port for ALB | `number` | `443` |
| alb_enable_http | Enable HTTP ingress rule | `bool` | `true` |
| alb_enable_https | Enable HTTPS ingress rule | `bool` | `true` |

### Optional Variables - ECS Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| ecs_ingress_from_alb_sg_id | ALB security group ID to allow ingress | `string` | `null` |
| ecs_container_port | Container port for ECS service | `number` | `8080` |
| ecs_additional_ingress_sg_ids | Additional security group IDs to allow ingress | `list(string)` | `[]` |

### Optional Variables - RDS Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| rds_ingress_from_ecs_sg_id | ECS security group ID to allow ingress | `string` | `null` |
| rds_port | Database port for RDS | `number` | `5432` |
| rds_additional_ingress_sg_ids | Additional security group IDs to allow ingress | `list(string)` | `[]` |
| rds_ingress_cidr_blocks | CIDR blocks allowed to access RDS | `list(string)` | `[]` |

### Optional Variables - VPC Endpoint Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| vpc_endpoint_ingress_cidr_blocks | CIDR blocks allowed to access VPC endpoints | `list(string)` | `[]` |
| vpc_endpoint_ingress_sg_ids | Security group IDs allowed to access VPC endpoints | `list(string)` | `[]` |
| vpc_endpoint_port | Port for VPC endpoint | `number` | `443` |

### Optional Variables - Custom Rules

| Name | Description | Type | Default |
|------|-------------|------|---------|
| custom_ingress_rules | List of custom ingress rules | `list(object)` | `[]` |
| custom_egress_rules | List of custom egress rules | `list(object)` | `[]` |
| enable_default_egress | Enable default egress rule (all outbound) | `bool` | `true` |

## Outputs

| Name | Description |
|------|-------------|
| security_group_id | ID of the security group |
| security_group_arn | ARN of the security group |
| security_group_name | Name of the security group |
| security_group_vpc_id | VPC ID of the security group |

## Best Practices

### 1. Security Group References Over CIDR Blocks

가능한 한 CIDR 블록보다 보안 그룹 참조를 사용하세요:

```hcl
# ✅ 좋은 예: 보안 그룹 참조 사용
ecs_ingress_from_alb_sg_id = module.alb_sg.security_group_id

# ❌ 나쁜 예: CIDR 블록 사용 (동적 IP 관리 어려움)
custom_ingress_rules = [{
  from_port   = 8080
  cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"]
  # ...
}]
```

### 2. Least Privilege Principle

필요한 포트와 소스만 허용하세요:

```hcl
# ✅ 좋은 예: 특정 포트와 소스
rds_ingress_from_ecs_sg_id = module.ecs_sg.security_group_id
rds_port                   = 5432

# ❌ 나쁜 예: 모든 트래픽 허용
rds_ingress_cidr_blocks = ["0.0.0.0/0"]
```

### 3. Type-Based Configuration

적절한 타입을 사용하여 일관된 규칙 적용:

```hcl
# ALB용 보안 그룹
type = "alb"

# ECS용 보안 그룹
type = "ecs"

# 완전 커스텀이 필요한 경우
type = "custom"
```

### 4. Descriptive Names and Tags

명확한 이름과 태그를 사용하세요:

```hcl
name        = "prod-api-ecs-sg"
description = "Security group for production API ECS service"

common_tags = {
  Environment = "production"
  Application = "api"
  ManagedBy   = "terraform"
  Component   = "ecs-service"
}
```

### 5. Layered Security

계층적 보안 그룹 구조를 사용하세요:

```
Internet → ALB SG (80, 443) → ECS SG (8080) → RDS SG (5432)
```

## Security Considerations

1. **Default Egress Rule**: 기본적으로 모든 아웃바운드 트래픽이 허용됩니다. 더 엄격한 제어가 필요한 경우 `enable_default_egress = false`로 설정하고 커스텀 이그레스 규칙을 사용하세요.

2. **Public Access**: ALB 보안 그룹 외에는 `0.0.0.0/0` CIDR 블록을 사용하지 마세요.

3. **Security Group References**: 가능한 한 보안 그룹 참조를 사용하여 트래픽을 제한하세요.

4. **Regular Audits**: 정기적으로 보안 그룹 규칙을 검토하고 불필요한 규칙을 제거하세요.

5. **VPC Flow Logs**: VPC Flow Logs를 활성화하여 네트워크 트래픽을 모니터링하세요.

## Common Patterns

### Pattern 1: Three-Tier Web Application

```hcl
# Web Tier (ALB)
module "web_sg" {
  source = "../../modules/security-group"
  type   = "alb"
  # ...
}

# Application Tier (ECS)
module "app_sg" {
  source                     = "../../modules/security-group"
  type                       = "ecs"
  ecs_ingress_from_alb_sg_id = module.web_sg.security_group_id
  # ...
}

# Database Tier (RDS)
module "db_sg" {
  source                     = "../../modules/security-group"
  type                       = "rds"
  rds_ingress_from_ecs_sg_id = module.app_sg.security_group_id
  # ...
}
```

### Pattern 2: Microservices with Shared Database

```hcl
# ALB for all services
module "shared_alb_sg" {
  type = "alb"
  # ...
}

# Service 1
module "service1_ecs_sg" {
  type                       = "ecs"
  ecs_ingress_from_alb_sg_id = module.shared_alb_sg.security_group_id
  # ...
}

# Service 2
module "service2_ecs_sg" {
  type                       = "ecs"
  ecs_ingress_from_alb_sg_id = module.shared_alb_sg.security_group_id
  # ...
}

# Shared RDS
module "shared_rds_sg" {
  type = "rds"
  rds_additional_ingress_sg_ids = [
    module.service1_ecs_sg.security_group_id,
    module.service2_ecs_sg.security_group_id
  ]
  # ...
}
```

## Examples

더 많은 사용 예시는 [examples](./examples) 디렉토리를 참조하세요:

- [ALB Security Group](./examples/alb)
- [ECS Security Group](./examples/ecs)
- [RDS Security Group](./examples/rds)
- [VPC Endpoint Security Group](./examples/vpc-endpoint)
- [Custom Security Group](./examples/custom)

## License

MIT License
