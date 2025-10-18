# Advanced WAF Example

This example demonstrates a production-ready WAF configuration with comprehensive security features.

## Features

- ✅ **OWASP Top 10 Protection**: AWS Managed Rules
- ✅ **IP Reputation Filtering**: Block known malicious IPs
- ✅ **Anonymous IP Blocking**: Block VPN, Proxy, Tor traffic
- ✅ **Rate Limiting**: 3000 requests per 5 minutes per IP
- ✅ **Geo Blocking**: Block high-risk countries (KP, CU, IR, SY)
- ✅ **Kinesis Firehose Logging**: Centralized log collection
- ✅ **S3 Log Storage**: 7-year retention with lifecycle management
- ✅ **Field Redaction**: Protect sensitive headers (authorization, cookie)
- ✅ **CloudWatch Alarms**: Automated security monitoring

## Architecture

```
┌─────────────┐
│ API Gateway │───┐
└─────────────┘   │
                  │    ┌──────────────┐    ┌──────────────────┐    ┌─────────┐
┌─────────────┐   ├───→│ WAF WebACL   │───→│ Kinesis Firehose │───→│ S3      │
│     ALB     │───┘    │              │    │                  │    │ Bucket  │
└─────────────┘        │ - OWASP      │    └──────────────────┘    └─────────┘
                       │ - Rate Limit │              │
                       │ - Geo Block  │              ↓
                       │ - IP Rep     │    ┌──────────────────┐
                       └──────────────┘    │   CloudWatch     │
                                           │   Logs & Alarms  │
                                           └──────────────────┘
```

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Resource Association

After deploying, associate the WAF with your resources:

### ALB Association

```hcl
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = module.waf.web_acl_arn
}
```

### API Gateway Association

```hcl
resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = aws_apigatewayv2_stage.prod.arn
  web_acl_arn  = module.waf.web_acl_arn
}
```

## Monitoring

### CloudWatch Metrics

View real-time metrics in AWS Console:

```
Console → CloudWatch → Metrics → AWS/WAFV2
WebACL: prod-api-gateway-waf
```

Key metrics:
- **AllowedRequests**: Requests passing through WAF
- **BlockedRequests**: Requests blocked by WAF rules
- **CountedRequests**: Requests matching count-only rules

### CloudWatch Alarms

This example creates two alarms:

1. **High Blocked Requests**: Alerts when >1000 requests blocked in 5 minutes
2. **Rate Limit Triggered**: Alerts when rate limiting activates

### WAF Logs

Logs are stored in S3 with the following structure:

```
s3://prod-waf-logs-{account-id}/
└── waf-logs/
    ├── year=2025/
    │   └── month=10/
    │       └── day=18/
    │           └── {timestamp}.json.gz
    └── errors/ (if any delivery failures)
```

Query logs using Amazon Athena:

```sql
CREATE EXTERNAL TABLE waf_logs (
  timestamp bigint,
  formatVersion int,
  webaclId string,
  terminatingRuleId string,
  action string,
  httpRequest struct<
    clientIp:string,
    country:string,
    uri:string,
    requestId:string
  >
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://prod-waf-logs-{account-id}/waf-logs/';

-- Query blocked requests
SELECT
  from_unixtime(timestamp/1000) as request_time,
  httpRequest.clientIp,
  httpRequest.country,
  httpRequest.uri,
  terminatingRuleId
FROM waf_logs
WHERE action = 'BLOCK'
ORDER BY timestamp DESC
LIMIT 100;
```

## Security Configuration

### Blocked Countries

Currently blocking:
- **KP**: North Korea
- **CU**: Cuba
- **IR**: Iran
- **SY**: Syria

Adjust based on your compliance requirements.

### Redacted Fields

The following fields are redacted in logs:
- `authorization` header
- `cookie` header

This prevents accidental exposure of sensitive authentication data.

### Rate Limiting

Current setting: **3000 requests per 5 minutes per IP**

Adjust based on your traffic patterns:

```hcl
rate_limit = 5000  # For higher traffic
rate_limit = 1000  # For more restrictive
```

## Cost Estimate

Production configuration costs:

- **WebACL**: $5.00/month
- **6 Rules**: $6.00/month
  - OWASP Top 10
  - IP Reputation
  - Anonymous IP
  - Rate Limiting
  - Geo Blocking
- **Requests**: $0.60 per 1M requests
- **Kinesis Firehose**: $0.029 per GB ingested
- **S3 Storage**: $0.023 per GB/month (Standard)
- **Data Transfer**: $0.09 per GB (S3 → Athena)

**Total Base**: ~$11/month + usage charges

Example with 10M requests/month and 10GB logs:
- Base: $11
- Requests: $6
- Firehose: $0.29
- S3: $0.23
- **Total**: ~$17.50/month

## Compliance

This configuration helps meet:

- **PCI DSS**: WAF protection for payment systems
- **OWASP**: Top 10 vulnerability protection
- **SOC 2**: Logging and monitoring requirements
- **GDPR**: Geographic data restrictions (if needed)

## Operational Runbook

### High Blocked Request Alert

1. Check CloudWatch alarm details
2. Review WAF logs in S3 or CloudWatch Insights
3. Identify terminating rule and IP patterns
4. Determine if legitimate traffic or attack
5. Adjust rules if false positive
6. Document incident

### False Positive Mitigation

If legitimate traffic is blocked:

1. Review sampled requests in WAF console
2. Identify specific rule causing blocks
3. Add rule exception or custom allow rule
4. Test with count action before applying
5. Monitor for 24 hours
6. Apply permanent fix

## Troubleshooting

### No Logs in S3

Check:
- Kinesis Firehose status
- IAM role permissions
- S3 bucket policy
- CloudWatch log groups for Firehose errors

### High WCU Usage

Monitor WebACL capacity:

```bash
aws wafv2 get-web-acl \
  --name prod-api-gateway-waf \
  --scope REGIONAL \
  --id <web-acl-id> \
  --query 'WebACL.Capacity'
```

Default limit: 1500 WCUs
If approaching limit, optimize rules or request increase.

## Clean Up

```bash
# Remove WAF associations first
terraform state rm aws_wafv2_web_acl_association.alb

# Then destroy
terraform destroy
```

**Warning**: Destroying will delete all WAF logs in S3 if versioning is not enabled.

## Next Steps

1. Associate with production resources
2. Configure SNS notifications for alarms
3. Set up Athena for log analysis
4. Create dashboard in CloudWatch or Grafana
5. Integrate with SIEM system
6. Regular review of blocked traffic patterns
