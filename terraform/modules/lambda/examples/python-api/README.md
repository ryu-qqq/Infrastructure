# Python API Lambda Example

This example demonstrates deploying a Python Lambda function configured for API workloads.

## Features

- **Python 3.11 Runtime**: Modern Python runtime with latest features
- **VPC Configuration**: Lambda deployed in VPC with security groups
- **CloudWatch Logs**: KMS-encrypted logs with 14-day retention
- **Dead Letter Queue**: SQS DLQ with KMS encryption for failed invocations
- **X-Ray Tracing**: Active tracing for performance monitoring
- **Versioning & Aliases**: Support for versioned deployments
- **Environment Variables**: Runtime configuration management
- **API Gateway Ready**: Lambda permission for API Gateway integration

## Architecture

```
API Gateway → Lambda (VPC) → [External APIs/Services]
                ↓
          CloudWatch Logs (KMS encrypted)
                ↓
          Dead Letter Queue (SQS, KMS encrypted)
```

## Prerequisites

1. **VPC Setup**: Existing VPC with private subnets
2. **Lambda Package**: Python code packaged as `.zip` file
3. **AWS Credentials**: Configured AWS credentials with appropriate permissions

## Usage

### 1. Create Lambda Deployment Package

```bash
# Create deployment package
cd examples/python-api
zip lambda_function.zip lambda_function.py

# Or with dependencies
pip install -r requirements.txt -t package/
cd package && zip -r ../lambda_function.zip . && cd ..
zip -g lambda_function.zip lambda_function.py
```

### 2. Configure Variables

Create a `terraform.tfvars` file:

```hcl
aws_region   = "ap-northeast-2"
environment  = "dev"
service_name = "example-api"
vpc_id       = "vpc-xxxxx"

# Optional: Custom IAM policies
custom_policy_arns = {
  dynamodb = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
  s3       = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Optional: Enable API Gateway integration
enable_api_gateway = true
```

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply changes
terraform apply
```

### 4. Test Lambda Function

```bash
# Invoke Lambda directly
aws lambda invoke \
  --function-name example-api-dev-api \
  --payload '{"httpMethod":"GET","path":"/health"}' \
  --region ap-northeast-2 \
  response.json

# View response
cat response.json
```

## Lambda Function Code

The example includes a complete API handler (`lambda_function.py`) with:

- **Health check endpoint**: `GET /health`
- **Get users**: `GET /api/v1/users?limit=10&offset=0`
- **Create user**: `POST /api/v1/users`
- **Error handling**: Proper error responses and logging
- **Input validation**: Request validation and sanitization

## Environment Variables

The Lambda function uses the following environment variables:

| Variable      | Description           | Default |
|---------------|-----------------------|---------|
| `ENVIRONMENT` | Environment name      | -       |
| `LOG_LEVEL`   | Logging level         | `INFO`  |
| `API_VERSION` | API version           | `v1`    |

## Monitoring

### CloudWatch Logs

View logs in CloudWatch Logs:

```bash
aws logs tail /aws/lambda/example-api-dev-api --follow
```

### X-Ray Traces

View traces in AWS X-Ray console for performance analysis.

### Dead Letter Queue

Check DLQ for failed invocations:

```bash
aws sqs receive-message \
  --queue-url https://sqs.ap-northeast-2.amazonaws.com/ACCOUNT_ID/example-api-dev-api-dlq \
  --region ap-northeast-2
```

## Cost Estimation

Approximate monthly costs for this example (dev environment):

- **Lambda**: $0.20 per 1M requests + $0.0000166667 per GB-second
- **CloudWatch Logs**: $0.50 per GB ingested + $0.03 per GB stored
- **X-Ray**: $5.00 per 1M traces recorded + $0.50 per 1M traces retrieved
- **SQS DLQ**: $0.40 per 1M requests

## Security Considerations

1. **KMS Encryption**: All logs and DLQ messages are encrypted with customer-managed KMS keys
2. **VPC Isolation**: Lambda runs in private subnets with controlled egress
3. **IAM Least Privilege**: Lambda role has minimal required permissions
4. **Security Groups**: Restricted network access through security groups

## Cleanup

```bash
terraform destroy
```

## Next Steps

1. **Add API Gateway**: Create API Gateway REST API for HTTP access
2. **Add Database**: Integrate with RDS or DynamoDB for data persistence
3. **Add Authentication**: Implement API key or JWT authentication
4. **Add Rate Limiting**: Configure API Gateway throttling
5. **Add CI/CD**: Automate deployment with GitHub Actions or CodePipeline

## Related Examples

- [Advanced Lambda Example](../advanced/) - Event-driven Lambda with EventBridge
- [Lambda with Layers](../layers/) - Using Lambda Layers for dependencies

## References

- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Lambda Python Programming Model](https://docs.aws.amazon.com/lambda/latest/dg/python-programming-model.html)
- [Lambda Module Documentation](../../README.md)
