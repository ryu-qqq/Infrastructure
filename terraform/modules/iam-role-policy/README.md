# IAM Role and Policy Module

재사용 가능한 IAM Role 및 Policy 관리 모듈입니다. ECS Task Role/Execution Role, RDS 접근, Secrets Manager, S3, CloudWatch Logs 등의 다양한 AWS 서비스 권한을 최소 권한 원칙에 따라 구성할 수 있습니다.

## Features

- **IAM Role 생성**: 커스터마이즈 가능한 IAM Role 및 Assume Role Policy
- **ECS Task Execution Policy**: ECR 이미지 풀, CloudWatch Logs 작성 권한
- **ECS Task Policy**: ECS 작업 런타임 권한
- **RDS Access Policy**: RDS 클러스터/인스턴스 접근 및 IAM 인증
- **Secrets Manager Policy**: 시크릿 읽기/쓰기/삭제 권한 세분화
- **S3 Access Policy**: 버킷 및 객체 레벨 권한 분리
- **CloudWatch Logs Policy**: 로그 그룹 생성 및 스트림 작성
- **KMS Integration**: 모든 정책에서 KMS 암호화 지원
- **AWS Managed Policies**: AWS 관리형 정책 연결 지원
- **Custom Inline Policies**: 사용자 정의 인라인 정책 추가

## Usage

### Basic IAM Role

```hcl
module "basic_role" {
  source = "../../"

  role_name          = "my-application-role"
  description        = "IAM role for my application"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  common_tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

### ECS Task Execution Role

```hcl
module "ecs_task_execution_role" {
  source = "../../"

  role_name          = "my-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # ECS Task Execution 권한 활성화
  enable_ecs_task_execution_policy = true
  ecr_repository_arns              = ["arn:aws:ecr:ap-northeast-2:123456789012:repository/my-app"]
  cloudwatch_log_group_arns        = ["arn:aws:logs:ap-northeast-2:123456789012:log-group:/ecs/my-app"]
  kms_key_arns                     = ["arn:aws:kms:ap-northeast-2:123456789012:key/abcd-1234"]
}
```

### ECS Task Role with RDS and Secrets Manager

```hcl
module "ecs_task_role" {
  source = "../../"

  role_name          = "my-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # ECS Task 런타임 권한
  enable_ecs_task_policy = true

  # RDS 접근 권한
  enable_rds_policy  = true
  rds_cluster_arns   = ["arn:aws:rds:ap-northeast-2:123456789012:cluster:my-db-cluster"]

  # Secrets Manager 접근 권한
  enable_secrets_manager_policy = true
  secrets_manager_secret_arns   = [
    "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:my-db-password-abc123"
  ]

  # KMS 복호화 권한
  kms_key_arns = ["arn:aws:kms:ap-northeast-2:123456789012:key/abcd-1234"]
}
```

### S3 Access with Read/Write Permissions

```hcl
module "s3_access_role" {
  source = "../../"

  role_name          = "my-s3-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # S3 접근 권한
  enable_s3_policy = true
  s3_bucket_arns   = ["arn:aws:s3:::my-bucket"]
  s3_object_arns   = ["arn:aws:s3:::my-bucket/*"]
  s3_allow_write   = true
  s3_allow_list    = true

  # KMS 암호화 권한
  kms_key_arns = ["arn:aws:kms:ap-northeast-2:123456789012:key/abcd-1234"]
}
```

### Minimal Permissions (Least Privilege)

```hcl
module "minimal_role" {
  source = "../../"

  role_name          = "my-minimal-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # CloudWatch Logs만 활성화 (최소 권한)
  enable_cloudwatch_logs_policy    = true
  cloudwatch_log_group_arns        = [
    "arn:aws:logs:ap-northeast-2:123456789012:log-group:/aws/lambda/my-function"
  ]
  cloudwatch_allow_create_log_group = false

  # 특정 Secrets만 읽기 권한
  enable_secrets_manager_policy = true
  secrets_manager_secret_arns   = [
    "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:my-api-key-abc123"
  ]
  secrets_manager_allow_create = false
  secrets_manager_allow_update = false
  secrets_manager_allow_delete = false
}
```

### Custom Inline Policies

```hcl
module "custom_role" {
  source = "../../"

  role_name          = "my-custom-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # 커스텀 인라인 정책 추가
  custom_inline_policies = {
    dynamodb_access = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:Query"
          ]
          Resource = "arn:aws:dynamodb:ap-northeast-2:123456789012:table/my-table"
        }]
      })
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Inputs

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| role_name | Name of the IAM role to create | `string` |
| assume_role_policy | JSON policy document for the assume role policy | `string` |

### Optional Variables - Role Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| common_tags | Common tags to apply to all resources | `map(string)` | `{}` |
| description | Description of the IAM role | `string` | `""` |
| max_session_duration | Maximum session duration in seconds (3600-43200) | `number` | `3600` |
| permissions_boundary | ARN of the policy that is used to set the permissions boundary for the role | `string` | `null` |

### Optional Variables - Policy Attachments

| Name | Description | Type | Default |
|------|-------------|------|---------|
| attach_aws_managed_policies | List of AWS managed policy ARNs to attach to the role | `list(string)` | `[]` |

### Optional Variables - ECS Policies

| Name | Description | Type | Default |
|------|-------------|------|---------|
| ecr_repository_arns | List of ECR repository ARNs for image pull permissions | `list(string)` | `[]` |
| ecs_cluster_arns | List of ECS cluster ARNs to restrict DescribeTasks and ListTasks permissions | `list(string)` | `[]` |
| enable_ecs_task_execution_policy | Enable standard ECS task execution policy (ECR, CloudWatch Logs) | `bool` | `false` |
| enable_ecs_task_policy | Enable ECS task role policy with basic permissions | `bool` | `false` |
| kms_key_arns | List of KMS key ARNs for decryption permissions | `list(string)` | `[]` |

### Optional Variables - RDS Policy

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_rds_policy | Enable RDS access policy | `bool` | `false` |
| rds_cluster_arns | List of RDS cluster ARNs for database access | `list(string)` | `[]` |
| rds_db_instance_arns | List of RDS DB instance ARNs for database access | `list(string)` | `[]` |
| rds_iam_db_user_arns | List of RDS DB user ARNs for IAM database authentication | `list(string)` | `[]` |

### Optional Variables - Secrets Manager Policy

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_secrets_manager_policy | Enable Secrets Manager access policy | `bool` | `false` |
| secrets_manager_secret_arns | List of Secrets Manager secret ARNs for read access | `list(string)` | `[]` |
| secrets_manager_allow_create | Allow creating new secrets | `bool` | `false` |
| secrets_manager_allow_update | Allow updating existing secrets | `bool` | `false` |
| secrets_manager_allow_delete | Allow deleting secrets | `bool` | `false` |

### Optional Variables - S3 Policy

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_s3_policy | Enable S3 access policy | `bool` | `false` |
| s3_allow_list | Allow listing objects in S3 buckets | `bool` | `false` |
| s3_allow_write | Allow write operations to S3 (PutObject, DeleteObject) | `bool` | `false` |
| s3_bucket_arns | List of S3 bucket ARNs for access (bucket level) | `list(string)` | `[]` |
| s3_object_arns | List of S3 object ARNs for access (object level, typically bucket_arn/*) | `list(string)` | `[]` |

### Optional Variables - CloudWatch Logs Policy

| Name | Description | Type | Default |
|------|-------------|------|---------|
| cloudwatch_allow_create_log_group | Allow creating new log groups | `bool` | `false` |
| cloudwatch_log_group_arns | List of CloudWatch Log Group ARNs for write access | `list(string)` | `[]` |
| enable_cloudwatch_logs_policy | Enable CloudWatch Logs access policy | `bool` | `false` |

### Optional Variables - Custom Policies

| Name | Description | Type | Default |
|------|-------------|------|---------|
| custom_inline_policies | Map of custom inline policies to attach to the role | `map(object({ policy = string }))` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| role_arn | ARN of the IAM role |
| role_name | Name of the IAM role |
| role_id | ID of the IAM role |
| role_unique_id | Unique ID assigned by AWS to the IAM role |
| attached_policy_arns | List of AWS managed policy ARNs attached to the role |
| inline_policy_names | List of inline policy names attached to the role |

## Best Practices

### 1. Least Privilege Principle

항상 최소한의 권한만 부여하세요:

```hcl
# ❌ 나쁜 예: 와일드카드 사용
s3_object_arns = ["arn:aws:s3:::*/*"]

# ✅ 좋은 예: 특정 리소스만 지정
s3_object_arns = ["arn:aws:s3:::my-specific-bucket/app-data/*"]
```

### 2. Resource-Specific Permissions

가능한 한 구체적인 리소스 ARN을 사용하세요:

```hcl
# ✅ 좋은 예
rds_cluster_arns = [
  "arn:aws:rds:ap-northeast-2:123456789012:cluster:my-prod-cluster"
]
```

### 3. Separate Execution and Task Roles

ECS에서는 실행 역할과 태스크 역할을 분리하세요:

```hcl
# Execution Role: 컨테이너 시작에 필요한 권한
module "execution_role" {
  enable_ecs_task_execution_policy = true
  ecr_repository_arns              = [...]
}

# Task Role: 애플리케이션 런타임 권한
module "task_role" {
  enable_rds_policy            = true
  enable_secrets_manager_policy = true
}
```

### 4. KMS Integration

암호화된 리소스를 사용할 때는 KMS 권한을 함께 설정하세요:

```hcl
kms_key_arns = ["arn:aws:kms:ap-northeast-2:123456789012:key/abcd-1234"]
```

### 5. Tagging Strategy

일관된 태깅 전략을 사용하세요:

```hcl
common_tags = {
  Environment = "production"
  Project     = "my-project"
  ManagedBy   = "terraform"
  CostCenter  = "engineering"
}
```

## Security Considerations

1. **Permissions Boundary**: 필요한 경우 권한 경계를 설정하세요
2. **Session Duration**: 보안 요구사항에 맞게 세션 기간을 조정하세요
3. **Audit Logging**: CloudTrail을 통해 IAM 역할 사용을 모니터링하세요
4. **Regular Review**: 정기적으로 권한을 검토하고 불필요한 권한을 제거하세요

## Examples

더 많은 사용 예시는 [examples](./examples) 디렉토리를 참조하세요:

- [ECS Task Role](./examples/ecs-task-role)
- [ECS Task Execution Role](./examples/ecs-task-execution-role)
- [Minimal Permissions](./examples/minimal-permissions)

## License

MIT License
