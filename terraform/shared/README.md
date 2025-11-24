# Shared Infrastructure Resources

기존 AWS 리소스를 Terraform으로 Import하여 관리하고, SSM Parameter Store를 통해 다른 스택에서 참조할 수 있도록 하는 디렉토리입니다.

## 📋 목차

- [개요](#개요)
- [Import된 리소스 목록](#import된-리소스-목록)
- [사용 방법](#사용-방법)
- [디렉토리 구조](#디렉토리-구조)
- [크로스 스택 참조](#크로스-스택-참조)

---

## 개요

이 디렉토리는 이미 운영 중인 AWS 리소스들을 Terraform State로 가져와(Import) Infrastructure as Code로 관리하는 영역입니다.

### 주요 특징

- ✅ **기존 리소스 Import**: 운영 중인 리소스를 Terraform으로 가져오기
- ✅ **SSM Parameter 자동 생성**: Import 후 다른 스택에서 참조 가능하도록 SSM Parameters 자동 생성
- ✅ **Lifecycle 보존**: Import된 리소스의 기존 속성(태그, 설정 등)은 변경하지 않음
- ✅ **독립적 관리**: 각 리소스는 독립적인 Terraform 스택으로 관리
- ✅ **안전한 참조**: SSM Parameter Store를 통한 느슨한 결합

### Import vs 새 리소스 생성

| 구분 | Shared (이 디렉토리) | Templates |
|-----|---------------------|-----------|
| 목적 | 기존 리소스 Import | 새 리소스 생성 |
| 대상 | 이미 운영 중인 리소스 | 신규 프로젝트/환경 |
| 배포 | `terraform import` → `terraform apply` | `terraform apply` |
| 예시 | 프로덕션 ACM 인증서, Route53 Zone | 새 개발 환경 인증서 |

---

## Import된 리소스 목록

현재 Terraform으로 관리되는 **4개의 공유 리소스**가 있습니다.

### 1. ACM Certificate (*.set-of.com)

**위치**: `terraform/shared/acm/`

| 속성 | 값 |
|-----|-----|
| Certificate ARN | `arn:aws:acm:ap-northeast-2:646886795421:certificate/4241052f-dc09-4be1-8e4b-08902fce4729` |
| Domain | `*.set-of.com`, `set-of.com` (SAN) |
| Status | ISSUED |
| Validation | DNS (이미 완료) |

**SSM Parameters**:
- `/shared/connectly/certificate/wildcard-set-of.com/arn` - Certificate ARN
- `/shared/connectly/certificate/wildcard-set-of.com/domain` - Domain name

**사용 예시**:
```hcl
# ALB Listener에서 HTTPS 인증서 사용
data "aws_ssm_parameter" "cert_arn" {
  name = "/shared/connectly/certificate/wildcard-set-of.com/arn"
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_ssm_parameter.cert_arn.value

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
```

### 2. Route53 Hosted Zone (set-of.com)

**위치**: `terraform/shared/route53/`

| 속성 | 값 |
|-----|-----|
| Zone ID | `Z104656329CL6XBYE8OIJ` |
| Domain | `set-of.com` |
| Type | Public Hosted Zone |
| Record Count | 14 |

**Name Servers**:
- `ns-1067.awsdns-05.org`
- `ns-1663.awsdns-15.co.uk`
- `ns-395.awsdns-49.com`
- `ns-756.awsdns-30.net`

**SSM Parameters**:
- `/shared/connectly/dns/set-of-com/zone-id` - Hosted Zone ID
- `/shared/connectly/dns/set-of-com/name-servers` - Name Server 목록

**사용 예시**:
```hcl
# Route53 레코드 생성
data "aws_ssm_parameter" "zone_id" {
  name = "/shared/connectly/dns/set-of-com/zone-id"
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_ssm_parameter.zone_id.value
  name    = "api.set-of.com"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
```

### 3. RDS Instance (prod-shared-mysql)

**위치**: `terraform/shared/rds/`

| 속성 | 값 |
|-----|-----|
| Instance ID | `prod-shared-mysql` |
| Engine | MySQL 8.0.35 |
| Instance Class | db.t3.medium |
| Multi-AZ | Yes |
| Storage | 100 GB (gp3) |

**SSM Parameters**:
- `/shared/connectly/rds/db-instance-id` - RDS Instance ID
- `/shared/connectly/rds/endpoint` - RDS Endpoint
- `/shared/connectly/rds/port` - RDS Port
- `/shared/connectly/rds/security-group-id` - Security Group ID

**사용 예시**:
```hcl
# 애플리케이션에서 RDS 연결
data "aws_ssm_parameter" "db_endpoint" {
  name = "/shared/connectly/rds/endpoint"
}

data "aws_ssm_parameter" "db_port" {
  name = "/shared/connectly/rds/port"
}

resource "aws_ecs_task_definition" "app" {
  family = "my-app"

  container_definitions = jsonencode([{
    name = "app"
    environment = [
      {
        name  = "DB_HOST"
        value = data.aws_ssm_parameter.db_endpoint.value
      },
      {
        name  = "DB_PORT"
        value = data.aws_ssm_parameter.db_port.value
      }
    ]
  }])
}
```

### 4. VPC (prod-shared-vpc)

**위치**: `terraform/shared/vpc/`

| 속성 | 값 |
|-----|-----|
| VPC ID | (Import 완료) |
| CIDR | 10.0.0.0/16 |
| Availability Zones | ap-northeast-2a, 2b, 2c |
| NAT Gateways | Multi-AZ |

**SSM Parameters**:
- `/shared/connectly/vpc/vpc-id` - VPC ID
- `/shared/connectly/vpc/public-subnet-ids` - Public Subnet IDs
- `/shared/connectly/vpc/private-subnet-ids` - Private Subnet IDs

**사용 예시**:
```hcl
# ECS Service를 Private Subnet에 배포
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/connectly/vpc/vpc-id"
}

data "aws_ssm_parameter" "private_subnets" {
  name = "/shared/connectly/vpc/private-subnet-ids"
}

resource "aws_ecs_service" "app" {
  name    = "my-app"
  cluster = aws_ecs_cluster.main.id

  network_configuration {
    subnets         = split(",", data.aws_ssm_parameter.private_subnets.value)
    security_groups = [aws_security_group.app.id]
  }
}
```

---

## 사용 방법

### 1. Import 프로세스

```bash
# 1. 리소스 디렉토리로 이동
cd terraform/shared/acm

# 2. Terraform 초기화
terraform init

# 3. 기존 리소스 Import
terraform import aws_acm_certificate.main "arn:aws:acm:..."

# 4. Plan으로 변경사항 확인
terraform plan

# 5. Apply로 SSM Parameters 생성
terraform apply
```

### 2. 다른 스택에서 참조

```hcl
# 1. SSM Parameter 조회
data "aws_ssm_parameter" "cert_arn" {
  name = "/shared/connectly/certificate/wildcard-set-of.com/arn"
}

# 2. 값 사용
resource "aws_lb_listener" "https" {
  certificate_arn = data.aws_ssm_parameter.cert_arn.value
  # ...
}
```

### 3. 새 리소스 Import 추가

새로운 기존 리소스를 Import하려면:

1. **Templates에서 복사**: `templates/` 디렉토리에서 해당 리소스 타입 템플릿 복사
2. **설정 수정**: `terraform.tfvars`에 실제 값 입력, `provider.tf`에 S3 backend 설정
3. **Lifecycle 설정**: `ignore_changes`에 Import 시 변경하지 않을 속성 추가
4. **Import 실행**: `import.sh` 스크립트로 Import
5. **문서 업데이트**: 이 README.md와 CHANGELOG.md에 추가

---

## 디렉토리 구조

```
terraform/shared/
├── README.md              # 이 파일
├── CHANGELOG.md           # 변경 이력
├── acm/                   # *.set-of.com ACM 인증서
│   ├── certificate.tf
│   ├── outputs.tf         # SSM Parameters 생성
│   ├── import.sh
│   └── terraform.tfvars
├── route53/               # set-of.com Hosted Zone
│   ├── hosted_zone.tf
│   ├── outputs.tf         # SSM Parameters 생성
│   ├── import.sh
│   └── terraform.tfvars
├── rds/                   # prod-shared-mysql RDS
│   ├── db_instance.tf
│   ├── outputs.tf         # SSM Parameters 생성
│   ├── import.sh
│   └── terraform.tfvars
└── vpc/                   # prod-shared-vpc VPC
    ├── vpc.tf
    ├── outputs.tf         # SSM Parameters 생성
    ├── import.sh
    └── terraform.tfvars
```

---

## 크로스 스택 참조

### SSM Parameter 네이밍 규칙

```
/shared/{project}/{category}/{resource-name}/{attribute}

예시:
/shared/connectly/certificate/wildcard-set-of.com/arn
/shared/connectly/dns/set-of-com/zone-id
/shared/connectly/rds/endpoint
/shared/connectly/vpc/vpc-id
```

### 참조 패턴

```hcl
# 1. Data Source로 조회
data "aws_ssm_parameter" "resource" {
  name = "/shared/connectly/{category}/{resource-name}/{attribute}"
}

# 2. 값 사용
resource "aws_resource" "example" {
  attribute = data.aws_ssm_parameter.resource.value
}

# 3. StringList 타입 처리 (서브넷 등)
resource "aws_resource" "example" {
  subnets = split(",", data.aws_ssm_parameter.subnet_ids.value)
}
```

---

## 베스트 프랙티스

### 1. Import 시 Lifecycle 설정

```hcl
resource "aws_route53_zone" "main" {
  name = var.domain_name

  lifecycle {
    ignore_changes = [
      name,             # Import된 도메인명은 변경 불가
      vpc,              # VPC 연결 보존
      tags,             # 기존 태그 보존
      tags_all          # Provider default_tags 충돌 방지
    ]
  }
}
```

### 2. IAM 권한

**Terraform 실행 Role 필요 권한**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:*",
        "acm:*",
        "rds:*",
        "ec2:*",
        "ssm:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. 변경 영향 분석

Import된 리소스 변경 전:

```bash
# 1. 어떤 스택에서 SSM Parameter를 사용하는지 확인
aws ssm get-parameter --name "/shared/connectly/certificate/wildcard-set-of.com/arn"

# 2. 각 Consumer 스택에서 영향 분석
cd terraform/application
terraform plan

# 3. 주의해서 변경
terraform apply
```

---

## Troubleshooting

### Import 실패 - 태그 권한

**증상**:
```
Error: listing tags for Route 53: AccessDenied
```

**해결**:
```hcl
# lifecycle에 tags, tags_all 추가
lifecycle {
  ignore_changes = [tags, tags_all]
}
```

### SSM Parameter 조회 실패

**증상**:
```
Error: ParameterNotFound: /shared/connectly/...
```

**해결**:
```bash
# 1. Parameter 존재 확인
aws ssm get-parameter --name "/shared/connectly/..."

# 2. 리전 확인
aws ssm get-parameter --name "/shared/connectly/..." --region ap-northeast-2

# 3. Producer 스택 재배포
cd terraform/shared/acm
terraform apply
```

---

## 관련 문서

- [Templates README](../templates/README_NEW.md) - 새 리소스 생성 템플릿
- [Infrastructure Governance](../../docs/governance/infrastructure_governance.md)
- [Terraform Best Practices](../../docs/guides/terraform-best-practices.md)

---

**Last Updated**: 2025-11-23
**Maintained By**: Platform Team
