# Route53 Record Module

재사용 가능한 Route53 DNS 레코드 생성 모듈입니다.

## Features

- **Simple Records**: A, AAAA, CNAME, TXT, MX 등 기본 DNS 레코드 지원
- **Alias Records**: ALB, CloudFront 등 AWS 리소스를 위한 Alias 레코드
- **Routing Policies**: Weighted, Geolocation, Failover 라우팅 정책 지원
- **Health Checks**: Route53 Health Check 연동
- **Validation**: 입력 값 검증 및 안전한 설정

## Usage

### Basic A Record

```hcl
module "api_record" {
  source = "../../modules/route53-record"

  zone_id = "Z1234567890ABC"
  name    = "api.set-of.com"
  type    = "A"
  ttl     = 300
  records = ["203.0.113.10"]
}
```

### Alias Record for ALB

```hcl
module "app_record" {
  source = "../../modules/route53-record"

  zone_id = "Z1234567890ABC"
  name    = "app.set-of.com"
  type    = "A"

  alias_configuration = {
    name                   = "alb-123456.ap-northeast-2.elb.amazonaws.com"
    zone_id                = "Z1234567890DEF"
    evaluate_target_health = true
  }
}
```

### Weighted Routing (Canary Deployment)

```hcl
module "canary_primary" {
  source = "../../modules/route53-record"

  zone_id        = "Z1234567890ABC"
  name           = "api.set-of.com"
  type           = "A"
  ttl            = 60
  records        = ["203.0.113.10"]
  set_identifier = "primary-90"

  weighted_routing_policy = {
    weight = 90
  }
}

module "canary_new" {
  source = "../../modules/route53-record"

  zone_id        = "Z1234567890ABC"
  name           = "api.set-of.com"
  type           = "A"
  ttl            = 60
  records        = ["203.0.113.20"]
  set_identifier = "canary-10"

  weighted_routing_policy = {
    weight = 10
  }
}
```

### Failover Routing with Health Check

```hcl
module "primary" {
  source = "../../modules/route53-record"

  zone_id         = "Z1234567890ABC"
  name            = "service.set-of.com"
  type            = "A"
  ttl             = 60
  records         = ["203.0.113.30"]
  set_identifier  = "primary"
  health_check_id = "abc123-health-check-id"

  failover_routing_policy = {
    type = "PRIMARY"
  }
}

module "secondary" {
  source = "../../modules/route53-record"

  zone_id        = "Z1234567890ABC"
  name           = "service.set-of.com"
  type           = "A"
  ttl            = 60
  records        = ["203.0.113.40"]
  set_identifier = "secondary"

  failover_routing_policy = {
    type = "SECONDARY"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| zone_id | The ID of the hosted zone | string | - | yes |
| name | The name of the DNS record | string | - | yes |
| type | The record type (A, AAAA, CNAME, etc.) | string | - | yes |
| ttl | The TTL in seconds | number | 300 | no |
| records | List of DNS record values | list(string) | null | no* |
| alias_configuration | Alias configuration for AWS resources | object | null | no* |
| weighted_routing_policy | Weighted routing policy | object | null | no |
| geolocation_routing_policy | Geolocation routing policy | object | null | no |
| failover_routing_policy | Failover routing policy | object | null | no |
| set_identifier | Unique identifier for routing policies | string | null | no |
| health_check_id | Health check ID to associate | string | null | no |
| allow_overwrite | Allow overwriting existing records | bool | false | no |

*Note: Either `records` or `alias_configuration` must be provided, but not both.

## Outputs

| Name | Description |
|------|-------------|
| name | The name of the DNS record |
| fqdn | The fully qualified domain name |
| type | The type of the DNS record |
| records | The values of the DNS record |

## Examples

See the `examples/` directory for more usage examples:

- `examples/basic/` - Simple DNS records
- `examples/advanced/` - Routing policies and health checks

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

## License

MIT
