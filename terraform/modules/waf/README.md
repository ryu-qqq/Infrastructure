# AWS WAF (Web Application Firewall) Module

재사용 가능한 AWS WAF WebACL 모듈로 웹 애플리케이션 보안을 강화합니다.

## Features

- ✅ **OWASP Top 10 보호**: AWS Managed Rules로 주요 웹 취약점 차단
- ✅ **Rate Limiting**: IP 기반 DDoS 및 무차별 대입 공격 방지
- ✅ **Geo Blocking**: 특정 국가 차단 (선택적)
- ✅ **IP Reputation**: AWS 관리형 악성 IP 차단
- ✅ **Anonymous IP 차단**: VPN, Proxy, Tor 차단 (선택적)
- ✅ **CloudWatch Metrics**: 실시간 모니터링 및 알람
- ✅ **Kinesis Firehose 로깅**: 중앙 집중식 로그 관리
- ✅ **Resource Association**: ALB, API Gateway, CloudFront 자동 연결
- ✅ **Custom Rules**: 사용자 정의 보안 규칙 추가
- ✅ **완전한 거버넌스 준수**: 표준 태그, 네이밍 규칙 적용

## Usage

### Basic Example

```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "api-gateway"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}

module "waf" {
  source = "../../modules/waf"

  name  = "prod-api-gateway-waf"
  scope = "REGIONAL" # REGIONAL for ALB/API Gateway, CLOUDFRONT for CloudFront

  # OWASP Top 10 보호
  enable_owasp_rules = true

  # Rate Limiting (2000 req/5min per IP)
  enable_rate_limiting = true
  rate_limit           = 2000

  # CloudWatch metrics
  enable_cloudwatch_metrics = true

  # Standard tags
  common_tags = module.common_tags.tags
}

# Associate with ALB
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = module.waf.web_acl_arn
}
```

### Advanced Example with Logging

```hcl
# Kinesis Firehose for WAF logs
resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  name        = "aws-waf-logs-${var.environment}"
  destination = "s3"

  s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.waf_logs.arn
    prefix     = "waf-logs/"
  }

  tags = module.common_tags.tags
}

module "waf" {
  source = "../../modules/waf"

  name        = "prod-app-waf"
  scope       = "REGIONAL"
  description = "WAF for production application"

  # AWS Managed Rules
  enable_owasp_rules   = true
  enable_ip_reputation = true
  enable_anonymous_ip  = true

  # Rate Limiting
  enable_rate_limiting = true
  rate_limit           = 3000

  # Geo Blocking
  enable_geo_blocking = true
  blocked_countries   = ["KP", "CU", "IR", "SY"]

  # Logging
  enable_logging        = true
  log_destination_arn   = aws_kinesis_firehose_delivery_stream.waf_logs.arn

  redacted_fields = [
    {
      type = "single_header"
      name = "authorization"
    },
    {
      type = "single_header"
      name = "cookie"
    }
  ]

  # CloudWatch
  enable_cloudwatch_metrics = true
  metric_name               = "prod-app-waf"
  sampled_requests_enabled  = true

  # Resource associations
  resource_arns = [
    aws_lb.main.arn,
    aws_api_gateway_stage.prod.arn
  ]

  common_tags = module.common_tags.tags
}
```

### CloudFront Example

```hcl
# Note: CloudFront requires WAF in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "cloudfront_waf" {
  source = "../../modules/waf"

  providers = {
    aws = aws.us_east_1
  }

  name  = "prod-cloudfront-waf"
  scope = "CLOUDFRONT"

  enable_owasp_rules      = true
  enable_rate_limiting    = true
  rate_limit              = 5000
  enable_cloudwatch_metrics = true

  common_tags = module.common_tags.tags
}

resource "aws_cloudfront_distribution" "main" {
  # ... other configuration ...

  web_acl_id = module.cloudfront_waf.web_acl_arn
}
```

### Custom Rules Example

```hcl
module "waf_with_custom_rules" {
  source = "../../modules/waf"

  name  = "prod-custom-waf"
  scope = "REGIONAL"

  enable_owasp_rules   = true
  enable_rate_limiting = true

  # Custom rules
  custom_rules = [
    {
      name     = "block-bad-user-agents"
      priority = 100
      action   = "block"

      statement = {
        byte_match_statement = {
          field_to_match        = "single_header"
          positional_constraint = "CONTAINS"
          search_string         = "BadBot"
        }
      }

      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "block-bad-user-agents"
        sampled_requests_enabled   = true
      }
    }
  ]

  common_tags = module.common_tags.tags
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

### Required

| Name | Description | Type |
|------|-------------|------|
| `name` | Name of the WAF WebACL (kebab-case) | `string` |
| `scope` | Scope of the WAF (`REGIONAL` or `CLOUDFRONT`) | `string` |
| `common_tags` | Common tags from common-tags module | `map(string)` |

### Optional - Security Rules

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_owasp_rules` | Enable AWS Managed OWASP Top 10 rules | `bool` | `true` |
| `enable_rate_limiting` | Enable IP-based rate limiting | `bool` | `true` |
| `rate_limit` | Max requests per 5-min period per IP | `number` | `2000` |
| `enable_geo_blocking` | Enable geographic blocking | `bool` | `false` |
| `blocked_countries` | Country codes to block (ISO 3166-1 alpha-2) | `list(string)` | `[]` |
| `enable_ip_reputation` | Enable AWS Managed IP reputation rules | `bool` | `true` |
| `enable_anonymous_ip` | Enable AWS Managed Anonymous IP rules | `bool` | `false` |

### Optional - Logging

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_logging` | Enable WAF logging to Kinesis Firehose | `bool` | `true` |
| `log_destination_arn` | Kinesis Firehose ARN for logs | `string` | `null` |
| `redacted_fields` | Fields to redact in logs | `list(object)` | `[]` |

### Optional - Monitoring

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_cloudwatch_metrics` | Enable CloudWatch metrics | `bool` | `true` |
| `metric_name` | CloudWatch metric name | `string` | `null` |
| `sampled_requests_enabled` | Enable sampled requests | `bool` | `true` |

### Optional - Advanced

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `custom_rules` | List of custom WAF rules | `list(object)` | `[]` |
| `default_action` | Default action (`allow` or `block`) | `string` | `"allow"` |
| `resource_arns` | Resource ARNs to associate | `list(string)` | `[]` |
| `description` | Description of the WAF WebACL | `string` | `null` |

## Outputs

| Name | Description |
|------|-------------|
| `web_acl_id` | WAF WebACL ID |
| `web_acl_arn` | WAF WebACL ARN |
| `web_acl_name` | WAF WebACL name |
| `web_acl_capacity` | WAF capacity units (WCUs) used |
| `cloudwatch_metric_name` | CloudWatch metric name |
| `enabled_features` | Summary of enabled features |
| `rate_limit_value` | Configured rate limit value |
| `blocked_countries` | List of blocked countries |

## WAF Rules Priority

Rules are evaluated in priority order (lower number = higher priority):

| Priority | Rule | Default Enabled |
|----------|------|-----------------|
| 10 | OWASP Top 10 (AWS Managed) | ✅ Yes |
| 20 | Rate Limiting | ✅ Yes |
| 30 | Geo Blocking | ❌ No |
| 40 | IP Reputation (AWS Managed) | ✅ Yes |
| 50 | Anonymous IP (AWS Managed) | ❌ No |
| 100+ | Custom Rules | As configured |

## OWASP Top 10 Protection

AWS Managed Rules provide protection against:

1. **SQL Injection**: Blocks SQL injection attempts
2. **Cross-Site Scripting (XSS)**: Prevents XSS attacks
3. **Local File Inclusion (LFI)**: Blocks LFI attempts
4. **Remote File Inclusion (RFI)**: Prevents RFI attacks
5. **PHP Injection**: Blocks PHP code injection
6. **HTTP Request Smuggling**: Prevents request smuggling
7. **Server-Side Includes (SSI)**: Blocks SSI injection
8. **Session Fixation**: Prevents session fixation
9. **Java Deserialization**: Blocks unsafe deserialization
10. **Known Vulnerable Paths**: Blocks common attack paths

## Rate Limiting Guidelines

| Application Type | Recommended Rate Limit |
|------------------|------------------------|
| Public API | 1000-2000 req/5min |
| Web Application | 2000-3000 req/5min |
| High-Traffic Service | 5000-10000 req/5min |
| Internal API | 500-1000 req/5min |

## Geo Blocking

Common blocked countries (adjust based on your use case):

```hcl
blocked_countries = [
  "KP", # North Korea
  "CU", # Cuba
  "IR", # Iran
  "SY", # Syria
  "SD"  # Sudan
]
```

## Cost Considerations

- **WebACL**: $5.00/month
- **Rules**: $1.00/month per rule
- **Requests**: $0.60 per 1M requests
- **WCU Overage**: $1.00 per WCU/month over 1500 default
- **Logging**: Kinesis Firehose data ingestion charges apply

## Monitoring and Alarms

Recommended CloudWatch alarms:

```hcl
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${module.waf.web_acl_name}-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 100

  dimensions = {
    WebACL = module.waf.web_acl_name
    Region = "ap-northeast-2"
    Rule   = "ALL"
  }
}
```

## Security Best Practices

1. **Enable OWASP Rules**: Always enable for production
2. **Configure Rate Limiting**: Prevent DDoS attacks
3. **Enable Logging**: Required for security audits
4. **Monitor Metrics**: Set up CloudWatch alarms
5. **Review Sampled Requests**: Investigate blocked traffic
6. **Regular Updates**: AWS Managed Rules auto-update
7. **Test Before Production**: Use `count` action to test rules

## Limitations

- **WebACL Limits**: 100 rules per WebACL
- **WCU Limits**: Default 1500 WCUs (can request increase)
- **Rate Limiting**: Minimum 100, maximum 20M requests
- **Geo Blocking**: Based on source IP geolocation
- **CloudFront Scope**: Must use `us-east-1` region

## Related Modules

- [common-tags](../common-tags/) - Standard resource tagging
- [alb](../alb/) - Application Load Balancer
- [cloudwatch-log-group](../cloudwatch-log-group/) - Log management

## Examples

- [Basic WAF](./examples/basic/) - Simple WAF with OWASP rules
- [Advanced WAF](./examples/advanced/) - Full-featured WAF with logging

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for version history.

## Contributing

See main repository [CONTRIBUTING.md](../../CONTRIBUTING.md).

## License

Maintained by Infrastructure Team.

---

**Module Version**: 1.0.0
**Last Updated**: 2025-10-18
**Jira**: [IN-141](https://ryuqqq.atlassian.net/browse/IN-141)
