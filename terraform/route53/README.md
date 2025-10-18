# Route53 DNS Infrastructure

Route53 Hosted Zone 및 DNS 레코드 관리를 위한 Terraform 코드입니다.

## Overview

`set-of.com` 도메인의 DNS를 중앙에서 관리하기 위한 인프라입니다. 공통 플랫폼 인프라의 일부로, 모든 서비스가 필요한 DNS 레코드를 추가할 수 있습니다.

### Features

- ✅ Route53 Hosted Zone 관리 (set-of.com)
- ✅ DNS 쿼리 로깅 (CloudWatch Logs 연동)
- ✅ Health Check 모니터링 (atlantis.set-of.com)
- ✅ 재사용 가능한 DNS 레코드 모듈
- ✅ 거버넌스 정책 준수 (필수 태그, 네이밍 규칙)
- ✅ 기존 리소스 Import 지원

## Architecture

```
Route53 Infrastructure
├── Hosted Zone (set-of.com)
│   ├── Name Servers (NS)
│   ├── SOA Record
│   └── DNS Records (A, CNAME, TXT, etc.)
├── Query Logging
│   └── CloudWatch Logs (/aws/route53/set-of.com)
└── Health Checks
    └── atlantis.set-of.com (HTTPS)
```

## Directory Structure

```
terraform/route53/
├── provider.tf          # Terraform and provider configuration
├── variables.tf         # Input variables
├── locals.tf           # Local values and tags
├── main.tf             # Main Route53 resources
├── outputs.tf          # Output values
├── README.md           # This file
└── IMPORT_GUIDE.md     # Guide for importing existing resources
```

## Prerequisites

1. **Terraform**: >= 1.5.0
2. **AWS Provider**: ~> 5.0
3. **AWS CLI**: Configured with appropriate credentials
4. **Existing Resources**: set-of.com Hosted Zone already created in AWS Console

## Getting Started

### 1. Initialize Terraform

```bash
cd terraform/route53
terraform init
```

### 2. Import Existing Hosted Zone

기존 AWS 콘솔에서 생성한 Hosted Zone을 import합니다:

```bash
# Zone ID 확인
aws route53 list-hosted-zones | grep set-of.com

# Import (Zone ID를 실제 값으로 대체)
terraform import aws_route53_zone.primary Z1234567890ABC
```

자세한 import 절차는 [IMPORT_GUIDE.md](./IMPORT_GUIDE.md)를 참고하세요.

### 3. Plan and Apply

```bash
# Plan - 변경사항 확인
terraform plan

# Apply - 인프라 생성/업데이트
terraform apply
```

### 4. Verify Deployment

```bash
# Outputs 확인
terraform output

# DNS 레코드 조회 테스트
dig set-of.com
dig atlantis.set-of.com
```

## Usage Examples

### Adding DNS Records

재사용 가능한 `route53-record` 모듈을 사용하여 DNS 레코드를 추가합니다:

#### A Record

```hcl
module "api_record" {
  source = "../modules/route53-record"

  zone_id = module.route53.hosted_zone_id
  name    = "api.set-of.com"
  type    = "A"
  ttl     = 300
  records = ["203.0.113.10"]
}
```

#### Alias Record for ALB

```hcl
module "app_alias" {
  source = "../modules/route53-record"

  zone_id = module.route53.hosted_zone_id
  name    = "app.set-of.com"
  type    = "A"

  alias_configuration = {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}
```

#### CNAME Record

```hcl
module "www_record" {
  source = "../modules/route53-record"

  zone_id = module.route53.hosted_zone_id
  name    = "www.set-of.com"
  type    = "CNAME"
  ttl     = 300
  records = ["set-of.com"]
}
```

### Monitoring and Health Checks

Health Check 상태 확인:

```bash
# AWS CLI로 Health Check 상태 확인
aws route53 get-health-check-status --health-check-id <HEALTH_CHECK_ID>

# CloudWatch에서 쿼리 로그 확인
aws logs tail /aws/route53/set-of.com --follow
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| aws_region | AWS region for Route53 resources | string | ap-northeast-2 | no |
| environment | Environment name | string | prod | no |
| domain_name | Primary domain name | string | set-of.com | no |
| enable_dnssec | Enable DNSSEC | bool | false | no |
| enable_query_logging | Enable query logging | bool | true | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| hosted_zone_id | The Hosted Zone ID |
| hosted_zone_name | The Hosted Zone name |
| name_servers | Name servers for the zone |
| zone_arn | The ARN of the hosted zone |
| atlantis_health_check_id | Atlantis health check ID |
| query_log_group_name | CloudWatch Log Group for queries |
| query_log_group_arn | CloudWatch Log Group ARN |

## Modules

### route53-record

재사용 가능한 DNS 레코드 생성 모듈입니다.

**위치**: `terraform/modules/route53-record/`

**지원 기능**:
- Simple records (A, AAAA, CNAME, TXT, MX, etc.)
- Alias records (ALB, CloudFront, S3)
- Weighted routing (Canary deployment)
- Geolocation routing
- Failover routing
- Health check integration

자세한 사용법은 [modules/route53-record/README.md](../modules/route53-record/README.md)를 참고하세요.

## Governance Compliance

### Required Tags

모든 리소스는 다음 필수 태그를 포함합니다:

- `Owner`: platform-team
- `CostCenter`: infrastructure
- `Lifecycle`: production
- `DataClass`: public
- `Service`: dns
- `Environment`: prod
- `Component`: route53

### Naming Conventions

- **Resources**: kebab-case (e.g., `route53-set-of-com`)
- **Variables**: snake_case (e.g., `domain_name`)
- **Hosted Zone**: 도메인 이름 그대로 (e.g., `set-of.com`)

### Security Best Practices

- ✅ Query logging enabled for audit trail
- ✅ Health checks for critical endpoints
- ✅ `prevent_destroy` lifecycle to prevent accidental deletion
- ✅ Terraform state encrypted in S3
- ✅ No hardcoded credentials

## Validation and Testing

### Terraform Validation

```bash
# Format check
terraform fmt -check -recursive

# Validation
terraform validate

# Security scan
tfsec .
checkov -d .
```

### DNS Validation

```bash
# Zone delegation test
dig NS set-of.com

# Record resolution test
dig atlantis.set-of.com

# Health check test
curl -I https://atlantis.set-of.com/healthz
```

## Maintenance

### Adding New DNS Records

1. 새 서비스의 Terraform 코드에서 `route53-record` 모듈 사용
2. `terraform plan` 실행하여 변경사항 확인
3. PR 생성 및 리뷰 요청
4. Merge 후 자동 배포

### Updating Existing Records

1. 해당 레코드의 Terraform 코드 수정
2. `terraform plan`으로 영향 범위 확인
3. TTL을 고려하여 배포 일정 계획
4. PR 생성 및 배포

### Importing New Resources

기존 AWS 콘솔에서 수동으로 생성한 리소스를 Terraform으로 가져오려면 [IMPORT_GUIDE.md](./IMPORT_GUIDE.md)를 참고하세요.

## Troubleshooting

### DNS 레코드가 반영되지 않음

**원인**: DNS propagation 지연 또는 TTL
**해결**:
```bash
# TTL 확인
dig +noall +answer set-of.com

# DNS 캐시 확인
dig @8.8.8.8 atlantis.set-of.com
dig @1.1.1.1 atlantis.set-of.com
```

### Health Check 실패

**원인**: 엔드포인트 접근 불가 또는 경로 문제
**해결**:
```bash
# 직접 테스트
curl -I https://atlantis.set-of.com/healthz

# Health Check 로그 확인
aws route53 get-health-check-status --health-check-id <ID>
```

### Terraform Plan에서 변경사항 감지

**원인**: Import 후 코드와 실제 리소스 설정 차이
**해결**: [IMPORT_GUIDE.md](./IMPORT_GUIDE.md#troubleshooting) 참고

## Related Documentation

- [IMPORT_GUIDE.md](./IMPORT_GUIDE.md) - Import 가이드
- [../modules/route53-record/README.md](../modules/route53-record/README.md) - 레코드 모듈 문서
- [AWS Route53 Documentation](https://docs.aws.amazon.com/route53/)
- [Terraform AWS Provider - Route53](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone)

## Support

문제가 발생하거나 질문이 있으면:

1. 이 문서의 Troubleshooting 섹션 확인
2. IMPORT_GUIDE.md 확인
3. Platform Team에 문의

## License

Internal use only - Property of the organization
