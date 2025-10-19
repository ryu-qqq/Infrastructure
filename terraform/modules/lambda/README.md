# Lambda Function Terraform Module

AWS Lambda 함수를 배포하고 관리하기 위한 재사용 가능한 Terraform 모듈입니다. IAM 역할 자동 생성, VPC 통합, CloudWatch Logs, Dead Letter Queue, 버전 관리, 별칭 지원 등 Lambda 함수 배포에 필요한 모든 기능을 포함합니다.

## Features

- ✅ 다양한 런타임 지원 (Python, Node.js, Java, Go, .NET, Ruby)
- ✅ IAM 역할 자동 생성 및 정책 관리
- ✅ VPC 구성 지원 (서브넷, 보안 그룹)
- ✅ 환경 변수 관리
- ✅ CloudWatch Logs 통합 (KMS 암호화 지원)
- ✅ Dead Letter Queue (DLQ) 자동 생성
- ✅ Lambda 버전 관리 및 별칭 지원
- ✅ X-Ray 트레이싱 통합
- ✅ Lambda Layers 지원
- ✅ Lambda 권한 관리 (API Gateway, S3 등)
- ✅ 표준화된 태그 자동 적용
- ✅ 포괄적인 변수 검증

## Usage

### Basic Example (Python Lambda)

```hcl
# Lambda Function Module - Basic Configuration
module "api_lambda" {
  source = "../../modules/lambda"

  # Required tags
  environment = "prod"
  service     = "user-api"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  project     = "user-service"

  # Lambda Configuration
  name        = "handler"
  description = "User API Lambda function"
  handler     = "lambda_function.lambda_handler"
  runtime     = "python3.11"
  timeout     = 30
  memory_size = 256

  # Code deployment
  filename         = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")

  # Environment variables
  environment_variables = {
    ENVIRONMENT = "prod"
    LOG_LEVEL   = "INFO"
  }
}
```

### Advanced Example with VPC and DLQ

```hcl
# Data sources
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    Type = "private"
  }
}

# KMS Key for CloudWatch Logs
resource "aws_kms_key" "logs" {
  description             = "KMS key for Lambda logs encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Name        = "lambda-logs-kms"
    Environment = "prod"
  }
}

# KMS Key for DLQ
resource "aws_kms_key" "dlq" {
  description             = "KMS key for Lambda DLQ encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Name        = "lambda-dlq-kms"
    Environment = "prod"
  }
}

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name        = "user-api-lambda-prod"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "user-api-lambda-prod"
    Environment = "prod"
  }
}

# Lambda Function with VPC and DLQ
module "api_lambda" {
  source = "../../modules/lambda"

  # Required tags
  environment = "prod"
  service     = "user-api"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  project     = "user-service"

  # Lambda Configuration
  name        = "handler"
  description = "User API Lambda function with VPC and DLQ"
  handler     = "lambda_function.lambda_handler"
  runtime     = "python3.11"
  timeout     = 60
  memory_size = 512

  # Code deployment (S3)
  s3_bucket        = "my-lambda-artifacts"
  s3_key           = "user-api/lambda.zip"
  s3_object_version = "v1.0.0"

  # Environment variables
  environment_variables = {
    ENVIRONMENT = "prod"
    LOG_LEVEL   = "INFO"
    DB_HOST     = "mydb.cluster.ap-northeast-2.rds.amazonaws.com"
    API_VERSION = "v1"
  }

  # VPC Configuration
  vpc_config = {
    subnet_ids         = data.aws_subnets.private.ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  # CloudWatch Logs
  create_log_group    = true
  log_retention_days  = 30
  log_kms_key_id      = aws_kms_key.logs.arn

  # Dead Letter Queue
  create_dlq                    = true
  dlq_message_retention_seconds = 1209600 # 14 days
  dlq_kms_key_id                = aws_kms_key.dlq.arn

  # X-Ray Tracing
  tracing_mode = "Active"

  # Versioning
  publish = true

  # Lambda Aliases
  aliases = {
    live = {
      description      = "Live production alias"
      function_version = "$LATEST"
      routing_config   = null
    }
    canary = {
      description      = "Canary deployment alias"
      function_version = "1"
      routing_config = {
        additional_version_weights = {
          "2" = 0.1  # 10% traffic to version 2
        }
      }
    }
  }

  # Lambda Permissions
  lambda_permissions = {
    api_gateway = {
      action     = "lambda:InvokeFunction"
      principal  = "apigateway.amazonaws.com"
      source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
    }
    s3_trigger = {
      action     = "lambda:InvokeFunction"
      principal  = "s3.amazonaws.com"
      source_arn = "arn:aws:s3:::my-uploads-bucket"
    }
  }

  # Custom IAM Policies
  custom_policy_arns = {
    dynamodb = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
    s3       = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  }

  # Additional tags
  additional_tags = {
    Component = "api"
    Runtime   = "python3.11"
  }
}

# Example API Gateway REST API (required for the Lambda permission below)
resource "aws_api_gateway_rest_api" "api" {
  name = "api-lambda-example"

  tags = {
    Environment = "prod"
    Service     = "api-service"
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.api_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}
```

### Example with Inline IAM Policy

```hcl
# Lambda with custom inline IAM policy
module "processor_lambda" {
  source = "../../modules/lambda"

  # Required tags
  environment = "prod"
  service     = "data-processor"
  team        = "data-team"
  owner       = "data@example.com"
  cost_center = "engineering"
  project     = "data-pipeline"

  # Lambda Configuration
  name        = "processor"
  description = "Data processing Lambda function"
  handler     = "index.handler"
  runtime     = "nodejs20.x"
  timeout     = 300
  memory_size = 1024

  # Code deployment
  filename         = "processor.zip"
  source_code_hash = filebase64sha256("processor.zip")

  # Inline IAM policy
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::my-data-bucket/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:ap-northeast-2:*:table/ProcessingResults"
      }
    ]
  })

  # Environment variables
  environment_variables = {
    BUCKET_NAME = "my-data-bucket"
    TABLE_NAME  = "ProcessingResults"
  }
}
```

### Example with Lambda Layers

```hcl
# Lambda Layer for dependencies
resource "aws_lambda_layer_version" "dependencies" {
  filename            = "dependencies-layer.zip"
  layer_name          = "python-dependencies"
  compatible_runtimes = ["python3.11"]

  source_code_hash = filebase64sha256("dependencies-layer.zip")
}

# Lambda with Layers
module "app_lambda" {
  source = "../../modules/lambda"

  # Required tags
  environment = "prod"
  service     = "app-service"
  team        = "app-team"
  owner       = "app@example.com"
  cost_center = "engineering"
  project     = "main-app"

  # Lambda Configuration
  name        = "app-handler"
  handler     = "app.handler"
  runtime     = "python3.11"
  timeout     = 30
  memory_size = 256

  # Code deployment
  filename         = "app.zip"
  source_code_hash = filebase64sha256("app.zip")

  # Lambda Layers
  layers = [
    aws_lambda_layer_version.dependencies.arn
  ]
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
| environment | Environment name (dev, staging, prod) | `string` |
| service | Service name | `string` |
| team | Team responsible for the resource | `string` |
| owner | Owner email address | `string` |
| cost_center | Cost center for billing | `string` |
| project | Project name | `string` |
| name | Lambda function name suffix | `string` |
| handler | Lambda function handler | `string` |
| runtime | Lambda runtime | `string` |

### Lambda Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| function_name | Full Lambda function name (overrides auto-generated) | `string` | `""` |
| description | Description of the Lambda function | `string` | `""` |
| architectures | Instruction set architecture | `list(string)` | `["x86_64"]` |
| timeout | Function timeout in seconds | `number` | `30` |
| memory_size | Memory size in MB | `number` | `128` |
| reserved_concurrent_executions | Reserved concurrent executions | `number` | `-1` |
| publish | Whether to publish creation/change as new version | `bool` | `false` |

### Code Deployment

| Name | Description | Type | Default |
|------|-------------|------|---------|
| filename | Path to deployment package (local file) | `string` | `null` |
| s3_bucket | S3 bucket containing deployment package | `string` | `null` |
| s3_key | S3 key of deployment package | `string` | `null` |
| s3_object_version | S3 object version | `string` | `null` |
| source_code_hash | Base64-encoded SHA256 hash | `string` | `null` |
| layers | List of Lambda Layer ARNs | `list(string)` | `[]` |

### Environment Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| environment_variables | Map of environment variables | `map(string)` | `null` |

### VPC Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| vpc_config | VPC configuration | `object` | `null` |

### IAM Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| create_role | Whether to create IAM role | `bool` | `true` |
| lambda_role_arn | Existing IAM role ARN | `string` | `null` |
| custom_policy_arns | Map of custom policy ARNs | `map(string)` | `{}` |
| inline_policy | Inline IAM policy JSON | `string` | `null` |

### CloudWatch Logs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| create_log_group | Whether to create CloudWatch Log Group | `bool` | `true` |
| log_retention_days | Logs retention in days | `number` | `14` |
| log_kms_key_id | KMS key ID for logs encryption | `string` | `null` |

### Dead Letter Queue

| Name | Description | Type | Default |
|------|-------------|------|---------|
| create_dlq | Whether to create DLQ | `bool` | `false` |
| dlq_message_retention_seconds | DLQ message retention | `number` | `1209600` |
| dlq_kms_key_id | KMS key ID for DLQ encryption | `string` | `null` |

### Tracing

| Name | Description | Type | Default |
|------|-------------|------|---------|
| tracing_mode | X-Ray tracing mode | `string` | `null` |

### Ephemeral Storage

| Name | Description | Type | Default |
|------|-------------|------|---------|
| ephemeral_storage_size | Ephemeral storage size in MB | `number` | `null` |

### Aliases

| Name | Description | Type | Default |
|------|-------------|------|---------|
| aliases | Map of Lambda function aliases | `map(object)` | `{}` |

### Lambda Permissions

| Name | Description | Type | Default |
|------|-------------|------|---------|
| lambda_permissions | Map of Lambda permission configurations | `map(object)` | `{}` |

### Additional Tags

| Name | Description | Type | Default |
|------|-------------|------|---------|
| additional_tags | Additional tags to apply | `map(string)` | `{}` |

## Outputs

### Lambda Function

| Name | Description |
|------|-------------|
| function_name | Name of the Lambda function |
| function_arn | ARN of the Lambda function |
| function_qualified_arn | Qualified ARN of the Lambda function |
| function_invoke_arn | Invoke ARN for API Gateway integration |
| function_version | Latest published version |
| function_last_modified | Last modified date |
| function_source_code_hash | SHA256 hash of the package |
| function_source_code_size | Size in bytes of the .zip file |

### IAM Role

| Name | Description |
|------|-------------|
| role_arn | ARN of the IAM role |
| role_name | Name of the IAM role |
| role_id | ID of the IAM role |

### CloudWatch Log Group

| Name | Description |
|------|-------------|
| log_group_name | Name of the CloudWatch Log Group |
| log_group_arn | ARN of the CloudWatch Log Group |

### Dead Letter Queue

| Name | Description |
|------|-------------|
| dlq_arn | ARN of the Dead Letter Queue |
| dlq_url | URL of the Dead Letter Queue |

### Lambda Aliases

| Name | Description |
|------|-------------|
| aliases | Map of Lambda function aliases |

### Lambda Permissions

| Name | Description |
|------|-------------|
| permissions | Map of Lambda permissions |

## Supported Runtimes

- **Python**: `python3.9`, `python3.10`, `python3.11`, `python3.12`
- **Node.js**: `nodejs18.x`, `nodejs20.x`
- **Java**: `java17`, `java21`
- **.NET**: `dotnet6`, `dotnet8`
- **Go**: `go1.x`
- **Ruby**: `ruby3.2`, `ruby3.3`

## Governance Compliance

이 모듈은 다음 거버넌스 규칙을 준수합니다:

- ✅ **필수 태그**: Environment, Service, Team, Owner, CostCenter, Project
- ✅ **KMS 암호화**: CloudWatch Logs 및 DLQ에 KMS 암호화 지원
- ✅ **네이밍 컨벤션**: kebab-case 리소스명, snake_case 변수명
- ✅ **보안 검증**: tfsec 및 checkov 검증 통과

## Examples

자세한 사용 예시는 [examples](./examples/) 디렉토리를 참조하세요:

- [Python API Lambda](./examples/python-api/) - API Gateway 통합 예시

## Best Practices

### 1. 코드 배포

**S3 배포 권장** (프로덕션 환경):
```hcl
s3_bucket        = "my-lambda-artifacts"
s3_key           = "user-api/lambda-${var.version}.zip"
s3_object_version = var.version
```

**로컬 파일** (개발 환경):
```hcl
filename         = "lambda_function.zip"
source_code_hash = filebase64sha256("lambda_function.zip")
```

### 2. VPC 구성

Lambda를 VPC에 배포할 때:
- Private 서브넷 사용
- NAT Gateway를 통한 인터넷 액세스
- VPC 엔드포인트 활용 (S3, DynamoDB 등)

### 3. 로깅 및 모니터링

- CloudWatch Logs 활성화
- X-Ray 트레이싱 활성화 (`tracing_mode = "Active"`)
- CloudWatch Alarms 설정 (오류율, 실행 시간 등)

### 4. 보안

- 최소 권한 원칙 (IAM 정책)
- KMS 암호화 사용 (로그, DLQ, 환경 변수)
- VPC 격리 (민감한 워크로드)
- Secrets Manager 사용 (비밀번호, API 키)

### 5. 성능 최적화

- 적절한 메모리 크기 설정 (성능-비용 균형)
- 예약 동시 실행 설정 (안정적인 성능)
- Lambda Layers 활용 (의존성 분리)
- Provisioned Concurrency (지연 시간 최소화)

### 6. 비용 최적화

- 적절한 타임아웃 설정
- 로그 보존 기간 최적화
- ARM 아키텍처 고려 (`architectures = ["arm64"]`)
- 불필요한 VPC 구성 제거

## Troubleshooting

### Lambda가 VPC에서 인터넷에 액세스할 수 없음

**원인**: NAT Gateway 또는 VPC 엔드포인트 미구성

**해결**:
- Private 서브넷에 NAT Gateway 라우팅 추가
- 또는 VPC 엔드포인트 사용 (S3, DynamoDB 등)

### CloudWatch Logs가 생성되지 않음

**원인**: IAM 권한 부족

**해결**:
```hcl
create_role = true  # 모듈이 자동으로 필요한 권한 추가
```

### Lambda 실행 시간 초과

**원인**: 타임아웃 설정이 너무 짧음

**해결**:
```hcl
timeout = 300  # 최대 15분 (900초)
```

## Related Modules

- [CloudWatch Log Group Module](../cloudwatch-log-group/) - 로그 그룹 별도 관리
- [IAM Role Policy Module](../iam-role-policy/) - IAM 역할 별도 관리
- [Security Group Module](../security-group/) - 보안 그룹 별도 관리

## Changelog

변경 이력은 [CHANGELOG.md](./CHANGELOG.md)를 참조하세요.

## License

이 모듈은 MIT 라이선스를 따릅니다.

## Authors

Platform Team (platform@example.com)

## References

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Terraform AWS Lambda Function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)
