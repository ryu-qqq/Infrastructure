# Security Group Module

AWS Security Group 생성 및 규칙 관리를 위한 재사용 가능한 Terraform 모듈입니다.

## 버전

- **Current**: v1.0.0
- **Terraform**: >= 1.5.0
- **AWS Provider**: >= 5.0

## 개요

이 모듈은 다양한 AWS 서비스 유형(ALB, ECS, RDS, VPC Endpoint)에 최적화된 Security Group을 생성하고 관리합니다. 타입별로 사전 정의된 규칙 템플릿을 제공하며, 커스텀 ingress/egress 규칙도 지원합니다.

### 주요 기능

- **타입 기반 템플릿**: ALB, ECS, RDS, VPC Endpoint 전용 규칙 자동 구성
- **유연한 규칙 관리**: CIDR 기반 또는 Security Group 참조 방식 모두 지원
- **통합 태깅**: common-tags 모듈과 자동 통합
- **IPv6 지원**: IPv4/IPv6 dual-stack 규칙 설정 가능
- **안전한 생명주기**: create_before_destroy 전략 적용

### 지원 유형

| 타입 | 설명 | 주요 사용 사례 |
|------|------|--------------|
| `alb` | Application Load Balancer | HTTP/HTTPS 트래픽 수신 |
| `ecs` | ECS Service/Task | ALB로부터 트래픽 수신 |
| `rds` | RDS Database | ECS로부터 DB 트래픽 수신 |
| `vpc-endpoint` | VPC Endpoint | 프라이빗 AWS 서비스 액세스 |
| `custom` | 사용자 정의 | 특수 목적의 Security Group |

## 사용 방법

### ALB Security Group

```hcl
module "alb_sg" {
  source = "../../modules/security-group"

  name        = "prod-api-alb-sg"
  description = "Security group for API ALB"
  vpc_id      = var.vpc_id
  type        = "alb"

  # ALB 설정
  alb_enable_http          = true
  alb_enable_https         = true
  alb_ingress_cidr_blocks  = ["0.0.0.0/0"]  # 공개 접근
  alb_http_port            = 80
  alb_https_port           = 443

  # 필수 태깅 정보
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

### ECS Security Group

```hcl
module "ecs_sg" {
  source = "../../modules/security-group"

  name        = "prod-api-ecs-sg"
  description = "Security group for API ECS tasks"
  vpc_id      = var.vpc_id
  type        = "ecs"

  # ECS 설정 - ALB로부터만 트래픽 허용
  ecs_ingress_from_alb_sg_id = module.alb_sg.security_group_id
  ecs_container_port         = 8080

  # 추가 보안 그룹 허용 (예: bastion host)
  ecs_additional_ingress_sg_ids = [
    var.bastion_sg_id
  ]

  # 필수 태깅 정보
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

### RDS Security Group

```hcl
module "rds_sg" {
  source = "../../modules/security-group"

  name        = "prod-postgres-sg"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = var.vpc_id
  type        = "rds"

  # RDS 설정 - ECS로부터만 트래픽 허용
  rds_ingress_from_ecs_sg_id = module.ecs_sg.security_group_id
  rds_port                   = 5432  # PostgreSQL

  # 필수 태깅 정보
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  data_class = "confidential"  # DB는 민감 데이터
}
```

### VPC Endpoint Security Group

```hcl
module "vpc_endpoint_sg" {
  source = "../../modules/security-group"

  name        = "prod-s3-endpoint-sg"
  description = "Security group for S3 VPC endpoint"
  vpc_id      = var.vpc_id
  type        = "vpc-endpoint"

  # VPC Endpoint 설정
  vpc_endpoint_port = 443

  # Private 서브넷 CIDR 허용
  vpc_endpoint_ingress_cidr_blocks = [
    "10.0.0.0/19",
    "10.0.32.0/19"
  ]

  # 또는 특정 Security Group 허용
  vpc_endpoint_ingress_sg_ids = [
    module.ecs_sg.security_group_id
  ]

  # 필수 태깅 정보
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

### 커스텀 규칙이 있는 Security Group

```hcl
module "custom_sg" {
  source = "../../modules/security-group"

  name        = "prod-redis-sg"
  description = "Security group for Redis cluster"
  vpc_id      = var.vpc_id
  type        = "custom"

  # 커스텀 Ingress 규칙
  custom_ingress_rules = [
    {
      from_port                = 6379
      to_port                  = 6379
      protocol                 = "tcp"
      source_security_group_id = module.ecs_sg.security_group_id
      description              = "Allow Redis traffic from ECS"
    },
    {
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      cidr_block  = "10.0.0.0/16"
      description = "Allow Redis traffic from VPC"
    }
  ]

  # 커스텀 Egress 규칙 (기본 egress 비활성화 시)
  enable_default_egress = false
  custom_egress_rules = [
    {
      from_port  = 443
      to_port    = 443
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0"
      description = "Allow HTTPS outbound"
    }
  ]

  # 필수 태깅 정보
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

### 다계층 아키텍처 예제

```hcl
# 1. ALB Security Group (공개 접근)
module "alb_sg" {
  source = "../../modules/security-group"

  name        = "prod-web-alb-sg"
  vpc_id      = var.vpc_id
  type        = "alb"

  alb_enable_https        = true
  alb_enable_http         = false  # HTTPS만 허용
  alb_ingress_cidr_blocks = ["0.0.0.0/0"]

  environment  = "prod"
  service_name = "web-app"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}

# 2. ECS Security Group (ALB에서만 접근)
module "ecs_sg" {
  source = "../../modules/security-group"

  name        = "prod-web-ecs-sg"
  vpc_id      = var.vpc_id
  type        = "ecs"

  ecs_ingress_from_alb_sg_id = module.alb_sg.security_group_id
  ecs_container_port         = 3000

  environment  = "prod"
  service_name = "web-app"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}

# 3. RDS Security Group (ECS에서만 접근)
module "rds_sg" {
  source = "../../modules/security-group"

  name        = "prod-web-db-sg"
  vpc_id      = var.vpc_id
  type        = "rds"

  rds_ingress_from_ecs_sg_id = module.ecs_sg.security_group_id
  rds_port                   = 3306  # MySQL

  environment  = "prod"
  service_name = "web-app"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
  data_class   = "confidential"
}

# 출력값 활용
output "security_groups" {
  value = {
    alb_id = module.alb_sg.security_group_id
    ecs_id = module.ecs_sg.security_group_id
    rds_id = module.rds_sg.security_group_id
  }
}
```

## 입력 변수

### 필수 변수

| 변수명 | 타입 | 설명 | 검증 규칙 |
|--------|------|------|-----------|
| `name` | `string` | Security Group 이름 | kebab-case, 최대 255자 |
| `vpc_id` | `string` | VPC ID | - |
| `environment` | `string` | 환경 이름 | dev, staging, prod 중 하나 |
| `service_name` | `string` | 서비스 이름 | kebab-case |
| `team` | `string` | 담당 팀 | kebab-case |
| `owner` | `string` | 리소스 소유자 | 이메일 또는 kebab-case |
| `cost_center` | `string` | 비용 센터 | kebab-case |

### 선택적 변수

#### 일반 설정

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `description` | `string` | `"Managed by Terraform"` | Security Group 설명 |
| `type` | `string` | `"custom"` | SG 타입 (alb, ecs, rds, vpc-endpoint, custom) |
| `revoke_rules_on_delete` | `bool` | `false` | 삭제 시 모든 규칙 먼저 제거 |
| `enable_default_egress` | `bool` | `true` | 기본 egress 규칙 활성화 (모든 outbound 허용) |
| `project` | `string` | `"infrastructure"` | 프로젝트 이름 |
| `data_class` | `string` | `"internal"` | 데이터 분류 (confidential, internal, public) |
| `additional_tags` | `map(string)` | `{}` | 추가 태그 |

#### ALB 타입 설정

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `alb_enable_http` | `bool` | `true` | HTTP ingress 규칙 활성화 |
| `alb_enable_https` | `bool` | `true` | HTTPS ingress 규칙 활성화 |
| `alb_http_port` | `number` | `80` | HTTP 포트 |
| `alb_https_port` | `number` | `443` | HTTPS 포트 |
| `alb_ingress_cidr_blocks` | `list(string)` | `["0.0.0.0/0"]` | ALB 접근 허용 CIDR 블록 |

#### ECS 타입 설정

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `ecs_ingress_from_alb_sg_id` | `string` | `null` | ALB Security Group ID (ECS 접근 허용) |
| `ecs_container_port` | `number` | `8080` | 컨테이너 포트 |
| `ecs_additional_ingress_sg_ids` | `list(string)` | `[]` | 추가 허용 Security Group ID 목록 |

#### RDS 타입 설정

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `rds_ingress_from_ecs_sg_id` | `string` | `null` | ECS Security Group ID (RDS 접근 허용) |
| `rds_port` | `number` | `5432` | 데이터베이스 포트 (PostgreSQL 기본값) |
| `rds_additional_ingress_sg_ids` | `list(string)` | `[]` | 추가 허용 Security Group ID 목록 |
| `rds_ingress_cidr_blocks` | `list(string)` | `[]` | RDS 접근 허용 CIDR 블록 (주의해서 사용) |

#### VPC Endpoint 타입 설정

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `vpc_endpoint_port` | `number` | `443` | VPC Endpoint 포트 |
| `vpc_endpoint_ingress_cidr_blocks` | `list(string)` | `[]` | VPC Endpoint 접근 허용 CIDR 블록 |
| `vpc_endpoint_ingress_sg_ids` | `list(string)` | `[]` | VPC Endpoint 접근 허용 Security Group ID 목록 |

#### 커스텀 규칙

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `custom_ingress_rules` | `list(object)` | `[]` | 커스텀 ingress 규칙 목록 |
| `custom_egress_rules` | `list(object)` | `[]` | 커스텀 egress 규칙 목록 |

**커스텀 Ingress 규칙 객체 구조:**
```hcl
{
  from_port                = number
  to_port                  = number
  protocol                 = string
  cidr_block               = optional(string)      # IPv4 CIDR
  ipv6_cidr_block          = optional(string)      # IPv6 CIDR
  source_security_group_id = optional(string)      # Security Group ID
  description              = optional(string)
}
```

**커스텀 Egress 규칙 객체 구조:**
```hcl
{
  from_port                     = number
  to_port                       = number
  protocol                      = string
  cidr_block                    = optional(string)      # IPv4 CIDR
  ipv6_cidr_block               = optional(string)      # IPv6 CIDR
  destination_security_group_id = optional(string)      # Security Group ID
  description                   = optional(string)
}
```

**제약 조건:** 각 규칙마다 `cidr_block`, `ipv6_cidr_block`, `source_security_group_id` (또는 `destination_security_group_id`) 중 정확히 하나만 지정해야 합니다.

## 출력값

| 출력명 | 타입 | 설명 |
|--------|------|------|
| `security_group_id` | `string` | Security Group ID |
| `security_group_arn` | `string` | Security Group ARN |
| `security_group_name` | `string` | Security Group 이름 |
| `security_group_vpc_id` | `string` | Security Group이 속한 VPC ID |

## 리소스

이 모듈은 다음 리소스들을 생성합니다:

- `aws_security_group.this` - 메인 Security Group
- `aws_vpc_security_group_ingress_rule.*` - Ingress 규칙들
- `aws_vpc_security_group_egress_rule.*` - Egress 규칙들
- `module.tags` - common-tags 모듈 통합

## 보안 고려사항

### 🔴 중요: 최소 권한 원칙

1. **CIDR 블록 제한**: 가능한 한 좁은 범위의 CIDR 사용
   - ✅ 좋음: `["10.0.0.0/24"]`
   - ❌ 피함: `["0.0.0.0/0"]` (ALB 외에는 사용 지양)

2. **Security Group 참조 우선**: CIDR보다 Security Group 참조 방식 선호
   ```hcl
   # ✅ 권장: Security Group 참조
   ecs_ingress_from_alb_sg_id = module.alb_sg.security_group_id

   # ❌ 비권장: CIDR 블록
   custom_ingress_rules = [{
     cidr_block = "0.0.0.0/0"
     ...
   }]
   ```

3. **데이터베이스 보호**: RDS는 절대로 공개 CIDR 허용 금지
   ```hcl
   # ✅ 안전
   rds_ingress_from_ecs_sg_id = module.ecs_sg.security_group_id

   # ❌ 위험
   rds_ingress_cidr_blocks = ["0.0.0.0/0"]
   ```

4. **Egress 제한**: 민감한 환경에서는 기본 egress 비활성화
   ```hcl
   enable_default_egress = false
   custom_egress_rules = [
     # 필요한 egress만 명시적으로 허용
   ]
   ```

### 포트 범위 가이드

| 서비스 | 포트 | 프로토콜 | 설명 |
|--------|------|----------|------|
| HTTP | 80 | TCP | 비암호화 웹 트래픽 |
| HTTPS | 443 | TCP | 암호화 웹 트래픽 |
| PostgreSQL | 5432 | TCP | PostgreSQL 데이터베이스 |
| MySQL | 3306 | TCP | MySQL 데이터베이스 |
| Redis | 6379 | TCP | Redis 캐시 |
| MongoDB | 27017 | TCP | MongoDB 데이터베이스 |
| SSH | 22 | TCP | SSH 접근 (bastion만) |

## 태깅 전략

이 모듈은 `common-tags` 모듈과 통합되어 자동으로 필수 태그를 적용합니다:

```hcl
tags = merge(
  local.required_tags,  # common-tags 모듈에서 생성
  {
    Name        = var.name
    Description = var.description
    Type        = var.type
  }
)
```

**자동 적용되는 태그:**
- `Environment`: 환경 (dev, staging, prod)
- `Service`: 서비스 이름
- `Team`: 담당 팀
- `Owner`: 리소스 소유자
- `CostCenter`: 비용 센터
- `Project`: 프로젝트 이름
- `DataClass`: 데이터 분류
- `ManagedBy`: "terraform" (고정)
- `Name`, `Description`, `Type`: 모듈 자체 추가

## 의존성

- **Terraform Modules**: `common-tags` 모듈 (태깅)
- **AWS Provider**: >= 5.0 (VPC Security Group Rule 리소스 사용)

## 제한 사항

1. **규칙 개수 제한**: AWS Security Group은 최대 60개의 inbound/outbound 규칙 제한
2. **타입별 상호 배타성**: 한 Security Group에 여러 타입 혼용 불가 (예: alb + ecs 동시 사용 불가)
3. **IPv6 전용**: IPv6만 사용하려면 IPv4 CIDR 대신 `ipv6_cidr_block` 사용 필요
4. **Lifecycle**: `create_before_destroy` 전략으로 인해 이름 변경 시 일시적으로 두 개의 SG 존재

## 문제 해결

### 문제: "revoke all rules before deleting" 오류

**원인**: Security Group이 다른 리소스에서 참조 중일 때 삭제 시도

**해결책:**
```hcl
# 안전한 삭제를 위해 활성화
revoke_rules_on_delete = true
```

### 문제: "exactly one of cidr_block, ipv6_cidr_block, or source_security_group_id must be specified" 오류

**원인**: 커스텀 규칙에서 소스/목적지를 중복 지정하거나 누락

**해결책:**
```hcl
# ✅ 올바른 예 - 하나만 지정
custom_ingress_rules = [{
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = "sg-xxxx"  # 이것만 지정
  description              = "HTTPS from SG"
}]

# ❌ 잘못된 예 - 여러 개 지정
custom_ingress_rules = [{
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  cidr_block               = "10.0.0.0/16"
  source_security_group_id = "sg-xxxx"  # 중복!
}]
```

### 문제: 규칙이 생성되지 않음

**원인**: 타입과 맞지 않는 변수 사용

**해결책:** 타입에 맞는 변수 사용
```hcl
# type = "alb"일 때
alb_enable_http = true  # ✅ 작동

# type = "ecs"일 때
alb_enable_http = true  # ❌ 무시됨
ecs_ingress_from_alb_sg_id = "sg-xxxx"  # ✅ 작동
```

## 업그레이드 가이드

### v0.x → v1.0.0

주요 변경사항:
1. **AWS Provider 5.0 필수**: VPC Security Group Rule 리소스 사용
2. **타입 시스템 도입**: `type` 변수 추가 및 타입별 설정 분리
3. **커스텀 규칙 구조 변경**: Object 타입으로 변경

**마이그레이션 체크리스트:**
- [ ] Terraform >= 1.5.0 확인
- [ ] AWS Provider >= 5.0 업그레이드
- [ ] `type` 변수 추가 (기본값: "custom")
- [ ] 기존 `ingress_rules` → `custom_ingress_rules` 변경
- [ ] 기존 `egress_rules` → `custom_egress_rules` 변경
- [ ] `terraform plan`으로 변경사항 검토
- [ ] State 마이그레이션 필요 시 `terraform state mv` 사용

## 라이선스

이 모듈은 내부 인프라 코드로 관리됩니다.

## 작성자

**Owner**: Platform Team
**Maintainer**: platform@example.com

## 변경 이력

전체 변경 이력은 [CHANGELOG.md](./CHANGELOG.md)를 참조하세요.
