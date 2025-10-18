# Basic WAF Example

This example demonstrates the simplest WAF configuration with essential security features.

## Features

- ✅ OWASP Top 10 protection (AWS Managed Rules)
- ✅ IP-based rate limiting (2000 requests per 5 minutes)
- ✅ IP reputation filtering
- ✅ CloudWatch metrics and monitoring

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Associate with ALB

After creating the WAF, associate it with your Application Load Balancer:

```hcl
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = module.waf.web_acl_arn
}
```

## Associate with API Gateway

For API Gateway v2 (HTTP API):

```hcl
resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = aws_apigatewayv2_stage.prod.arn
  web_acl_arn  = module.waf.web_acl_arn
}
```

## Cost Estimate

- WebACL: ~$5/month
- 3 Rules (OWASP, Rate Limit, IP Reputation): ~$3/month
- Requests: $0.60 per 1M requests
- **Total Base**: ~$8/month + request charges

## Monitoring

View metrics in CloudWatch:

```
Namespace: AWS/WAFV2
Metrics:
  - AllowedRequests
  - BlockedRequests
  - CountedRequests
```

## Clean Up

```bash
terraform destroy
```
