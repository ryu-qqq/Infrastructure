# 3️⃣ Infrastructure 프로젝트 설정

**하이브리드 Terraform 인프라 구조 가이드 - Part 3**

**작성일**: 2025-10-22
**버전**: 2.0
**대상 독자**: 플랫폼 팀, 중앙 인프라 관리자

---

## 📋 이 가이드에서 다루는 내용

1. [Infrastructure 디렉토리 구조](#infrastructure-디렉토리-구조)
2. [SSM Parameters 생성 방법](#ssm-parameters-생성-방법)
3. [Network 모듈 배포](#network-모듈-배포)
4. [KMS 모듈 배포](#kms-모듈-배포)
5. [Shared RDS 설정](#shared-rds-설정)
6. [ECR 레포지토리 생성](#ecr-레포지토리-생성)

---

## Infrastructure 디렉토리 구조

**위치**: `/path/to/infrastructure/terraform/`

```
infrastructure/terraform/
├── network/              # VPC, Subnets, Route Tables
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf       # SSM Parameter exports
│   └── locals.tf
├── kms/                  # KMS Keys (7개)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf       # SSM Parameter exports
│   └── locals.tf
├── rds/                  # Shared RDS Instance
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── locals.tf
└── ecr/                  # ECR Repositories
    ├── fileflow/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf   # SSM Parameter exports
    ├── authhub/
    └── crawler/
```

### 모듈별 책임

- **network/**: VPC, Subnets, Route Tables, VPC Endpoints 생성 및 SSM Parameter Export
- **kms/**: 7개 KMS 키 생성 (cloudwatch-logs, secrets-manager, rds, s3, sqs, ssm, elasticache) 및 SSM Parameter Export
- **rds/**: Shared RDS 인스턴스 생성 및 SSM Parameter Export
- **ecr/**: 서비스별 ECR 레포지토리 생성 및 SSM Parameter Export

---

## SSM Parameters 생성 방법

### Network SSM Parameters

**파일**: `infrastructure/terraform/network/outputs.tf`

#### VPC ID Export

```hcl
# VPC ID
resource "aws_ssm_parameter" "vpc_id" {
  name        = "/shared/network/vpc-id"
  description = "VPC ID for cross-stack references"
  type        = "String"
  value       = aws_vpc.main.id

  tags = merge(
    local.required_tags,
    {
      Name      = "vpc-id-export"
      Component = "network"
    }
  )
}
```

#### Subnet IDs Export

```hcl
# Public Subnet IDs
resource "aws_ssm_parameter" "public_subnet_ids" {
  name        = "/shared/network/public-subnet-ids"
  description = "Public subnet IDs for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_subnet.public[*].id)

  tags = merge(
    local.required_tags,
    {
      Name      = "public-subnet-ids-export"
      Component = "network"
    }
  )
}

# Private Subnet IDs
resource "aws_ssm_parameter" "private_subnet_ids" {
  name        = "/shared/network/private-subnet-ids"
  description = "Private subnet IDs for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_subnet.private[*].id)

  tags = merge(
    local.required_tags,
    {
      Name      = "private-subnet-ids-export"
      Component = "network"
    }
  )
}

# Data Subnet IDs (RDS, ElastiCache 용)
resource "aws_ssm_parameter" "data_subnet_ids" {
  name        = "/shared/network/data-subnet-ids"
  description = "Data subnet IDs for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_subnet.data[*].id)

  tags = merge(
    local.required_tags,
    {
      Name      = "data-subnet-ids-export"
      Component = "network"
    }
  )
}
```

**주요 특징**:
- **StringList 타입**: Subnet IDs는 여러 값이므로 `StringList` 사용
- **join() 함수**: Terraform 리스트를 쉼표로 구분된 문자열로 변환
- **Consumer에서 참조**: `split(",", data.aws_ssm_parameter.private_subnet_ids.value)`로 다시 리스트로 변환

---

## Network 모듈 배포

### 1. Network 모듈 초기화

```bash
cd /path/to/infrastructure/terraform/network
terraform init
```

### 2. Network 모듈 배포

```bash
terraform plan
terraform apply
```

**생성 리소스**:
- VPC (10.0.0.0/16)
- Public Subnets (Multi-AZ, /20)
- Private Subnets (Multi-AZ, /19)
- Data Subnets (Multi-AZ, /20)
- Internet Gateway
- NAT Gateway (Multi-AZ)
- Route Tables (Public, Private, Data)
- VPC Endpoints (S3, DynamoDB, ECR, Secrets Manager)

### 3. SSM Parameters 확인

```bash
# 모든 네트워크 파라미터 조회
aws ssm get-parameters-by-path \
  --path /shared/network \
  --recursive \
  --region ap-northeast-2 \
  --query 'Parameters[*].[Name,Value]' \
  --output table

# 특정 파라미터 확인
aws ssm get-parameter \
  --name /shared/network/vpc-id \
  --region ap-northeast-2
```

**예상 결과**:
```
/shared/network/vpc-id                    vpc-0a1b2c3d4e5f6g7h8
/shared/network/public-subnet-ids         subnet-abc123,subnet-def456
/shared/network/private-subnet-ids        subnet-ghi789,subnet-jkl012
/shared/network/data-subnet-ids           subnet-mno345,subnet-pqr678
```

---

## KMS 모듈 배포

### KMS SSM Parameters

**파일**: `infrastructure/terraform/kms/outputs.tf`

#### 7개 KMS 키 Export

```hcl
# CloudWatch Logs KMS Key
resource "aws_ssm_parameter" "cloudwatch_logs_key_arn" {
  name        = "/shared/kms/cloudwatch-logs-key-arn"
  description = "CloudWatch Logs KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.cloudwatch-logs.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "cloudwatch-logs-key-arn-export"
      Component = "kms"
    }
  )
}

# Secrets Manager KMS Key
resource "aws_ssm_parameter" "secrets_manager_key_arn" {
  name        = "/shared/kms/secrets-manager-key-arn"
  description = "Secrets Manager KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.secrets-manager.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "secrets-manager-key-arn-export"
      Component = "kms"
    }
  )
}

# RDS KMS Key
resource "aws_ssm_parameter" "rds_key_arn" {
  name        = "/shared/kms/rds-key-arn"
  description = "RDS KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.rds.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "rds-key-arn-export"
      Component = "kms"
    }
  )
}

# S3 KMS Key
resource "aws_ssm_parameter" "s3_key_arn" {
  name        = "/shared/kms/s3-key-arn"
  description = "S3 KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.s3.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "s3-key-arn-export"
      Component = "kms"
    }
  )
}

# SQS KMS Key
resource "aws_ssm_parameter" "sqs_key_arn" {
  name        = "/shared/kms/sqs-key-arn"
  description = "SQS KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.sqs.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "sqs-key-arn-export"
      Component = "kms"
    }
  )
}

# SSM Parameter Store KMS Key
resource "aws_ssm_parameter" "ssm_key_arn" {
  name        = "/shared/kms/ssm-key-arn"
  description = "SSM Parameter Store KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.ssm.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "ssm-key-arn-export"
      Component = "kms"
    }
  )
}

# ElastiCache KMS Key
resource "aws_ssm_parameter" "elasticache_key_arn" {
  name        = "/shared/kms/elasticache-key-arn"
  description = "ElastiCache KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.elasticache.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "elasticache-key-arn-export"
      Component = "kms"
    }
  )
}
```

### KMS 모듈 배포

```bash
cd /path/to/infrastructure/terraform/kms
terraform init
terraform plan
terraform apply
```

**생성 리소스**:
- 7개 Customer Managed KMS Keys
- KMS Aliases (alias/cloudwatch-logs, alias/secrets-manager, etc.)
- Key Policies (각 KMS 키별 접근 권한)
- Automatic Key Rotation (활성화)

### SSM Parameters 확인

```bash
# 모든 KMS 파라미터 조회
aws ssm get-parameters-by-path \
  --path /shared/kms \
  --recursive \
  --region ap-northeast-2 \
  --query 'Parameters[*].[Name]' \
  --output table
```

**예상 결과**:
```
/shared/kms/cloudwatch-logs-key-arn
/shared/kms/secrets-manager-key-arn
/shared/kms/rds-key-arn
/shared/kms/s3-key-arn
/shared/kms/sqs-key-arn
/shared/kms/ssm-key-arn
/shared/kms/elasticache-key-arn
```

---

## Shared RDS 설정

### Shared RDS 인스턴스 생성

**파일**: `infrastructure/terraform/rds/main.tf`

#### Master Credentials 생성 및 저장

```hcl
# Random password for RDS master user
resource "random_password" "master" {
  length  = 32
  special = true
}

# Store master credentials in Secrets Manager
resource "aws_secretsmanager_secret" "rds_master" {
  name_prefix             = "${var.environment}-shared-mysql-master-"
  description             = "Master credentials for shared MySQL RDS instance"
  kms_key_id              = data.aws_ssm_parameter.secrets_manager_key_arn.value
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-master"
      Component = "rds"
    }
  )
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = aws_secretsmanager_secret.rds_master.id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.master.result
    engine   = "mysql"
    host     = aws_db_instance.shared.endpoint
    port     = 3306
  })
}
```

#### DB Subnet Group 및 Security Group

```hcl
# DB Subnet Group
resource "aws_db_subnet_group" "shared" {
  name       = "${var.environment}-shared-mysql-subnet-group"
  subnet_ids = split(",", data.aws_ssm_parameter.data_subnet_ids.value)

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-subnet-group"
      Component = "rds"
    }
  )
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.environment}-shared-mysql-"
  description = "Security group for shared MySQL RDS instance"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  # Allow MySQL from private subnets
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "Allow MySQL from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-sg"
      Component = "rds"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
```

#### RDS Instance

```hcl
# RDS Instance
resource "aws_db_instance" "shared" {
  identifier = "${var.environment}-shared-mysql"

  # Engine
  engine               = "mysql"
  engine_version       = "8.0.42"
  instance_class       = var.environment == "prod" ? "db.t3.medium" : "db.t3.small"
  allocated_storage    = var.environment == "prod" ? 100 : 20
  max_allocated_storage = var.environment == "prod" ? 500 : 100
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id          = data.aws_ssm_parameter.rds_key_arn.value

  # Credentials
  username = "admin"
  password = random_password.master.result

  # Network
  db_subnet_group_name   = aws_db_subnet_group.shared.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High Availability
  multi_az = var.environment == "prod"

  # Backup
  backup_retention_period = var.environment == "prod" ? 7 : 3
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  skip_final_snapshot    = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.environment}-shared-mysql-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Performance Insights
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  performance_insights_enabled    = true
  performance_insights_kms_key_id = data.aws_ssm_parameter.cloudwatch_logs_key_arn.value

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.shared.name

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql"
      Component = "rds"
    }
  )
}

# DB Parameter Group
resource "aws_db_parameter_group" "shared" {
  name_prefix = "${var.environment}-shared-mysql-"
  family      = "mysql8.0"
  description = "Parameter group for shared MySQL RDS instance"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = var.environment == "prod" ? "200" : "100"
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-params"
      Component = "rds"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
```

### Shared RDS Outputs

**파일**: `infrastructure/terraform/rds/outputs.tf`

```hcl
output "db_instance_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.shared.identifier
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.shared.endpoint
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.shared.arn
}

output "db_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "master_secret_arn" {
  description = "ARN of master credentials secret"
  value       = aws_secretsmanager_secret.rds_master.arn
}

# SSM Parameter Export for Application projects
resource "aws_ssm_parameter" "shared_rds_identifier" {
  name        = "/shared/rds/${var.environment}/identifier"
  description = "Shared RDS instance identifier"
  type        = "String"
  value       = aws_db_instance.shared.identifier

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-identifier-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "shared_rds_endpoint" {
  name        = "/shared/rds/${var.environment}/endpoint"
  description = "Shared RDS instance endpoint"
  type        = "String"
  value       = aws_db_instance.shared.endpoint

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-endpoint-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "shared_rds_security_group_id" {
  name        = "/shared/rds/${var.environment}/security-group-id"
  description = "Shared RDS security group ID"
  type        = "String"
  value       = aws_security_group.rds.id

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-sg-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "shared_rds_master_secret_arn" {
  name        = "/shared/rds/${var.environment}/master-secret-arn"
  description = "Shared RDS master credentials secret ARN"
  type        = "String"
  value       = aws_secretsmanager_secret.rds_master.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-master-secret-export"
      Component = "rds"
    }
  )
}
```

### RDS 모듈 배포

```bash
cd /path/to/infrastructure/terraform/rds
terraform init
terraform plan
terraform apply
```

**생성 리소스**:
- RDS MySQL 인스턴스 (Multi-AZ)
- DB Subnet Group
- Security Group
- Parameter Group
- Master Credentials (Secrets Manager)
- Performance Insights
- CloudWatch Logs Export

### SSM Parameters 확인

```bash
# 환경별 RDS 파라미터 조회
aws ssm get-parameters-by-path \
  --path /shared/rds/prod \
  --recursive \
  --region ap-northeast-2 \
  --query 'Parameters[*].[Name,Value]' \
  --output table
```

**예상 결과**:
```
/shared/rds/prod/identifier                prod-shared-mysql
/shared/rds/prod/endpoint                  prod-shared-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com:3306
/shared/rds/prod/security-group-id         sg-0a1b2c3d4e5f6g7h8
/shared/rds/prod/master-secret-arn         arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:prod-shared-mysql-master-xxxxx
```

---

## ECR 레포지토리 생성

### ECR SSM Parameters

**파일**: `infrastructure/terraform/ecr/fileflow/outputs.tf`

```hcl
# ECR Repository URL
resource "aws_ssm_parameter" "ecr_repository_url" {
  name        = "/shared/ecr/fileflow-repository-url"
  description = "FileFlow ECR repository URL for cross-stack references"
  type        = "String"
  value       = aws_ecr_repository.fileflow.repository_url

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-ecr-url-export"
      Component = "ecr"
    }
  )
}

# ECR Repository ARN
resource "aws_ssm_parameter" "ecr_repository_arn" {
  name        = "/shared/ecr/fileflow-repository-arn"
  description = "FileFlow ECR repository ARN for cross-stack references"
  type        = "String"
  value       = aws_ecr_repository.fileflow.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-ecr-arn-export"
      Component = "ecr"
    }
  )
}
```

### ECR 모듈 배포

```bash
cd /path/to/infrastructure/terraform/ecr/fileflow
terraform init
terraform plan
terraform apply
```

**생성 리소스**:
- ECR Repository
- Lifecycle Policy (최근 10개 이미지만 유지)
- Image Scanning (푸시 시 자동 스캔)
- KMS Encryption (ECR 전용 KMS 키 사용)

### SSM Parameters 확인

```bash
# ECR 파라미터 조회
aws ssm get-parameters-by-path \
  --path /shared/ecr \
  --recursive \
  --region ap-northeast-2 \
  --query 'Parameters[*].[Name,Value]' \
  --output table
```

**예상 결과**:
```
/shared/ecr/fileflow-repository-url       646886795421.dkr.ecr.ap-northeast-2.amazonaws.com/fileflow
/shared/ecr/fileflow-repository-arn       arn:aws:ecr:ap-northeast-2:646886795421:repository/fileflow
```

---

## 전체 SSM Parameters 확인

모든 Infrastructure 모듈 배포 완료 후, 전체 SSM Parameters를 확인합니다:

```bash
# 모든 공유 파라미터 조회
aws ssm get-parameters-by-path \
  --path /shared \
  --recursive \
  --region ap-northeast-2 \
  --query 'Parameters[*].[Name]' \
  --output table
```

**예상 결과 (총 17개)**:
```
/shared/network/vpc-id
/shared/network/public-subnet-ids
/shared/network/private-subnet-ids
/shared/network/data-subnet-ids
/shared/kms/cloudwatch-logs-key-arn
/shared/kms/secrets-manager-key-arn
/shared/kms/rds-key-arn
/shared/kms/s3-key-arn
/shared/kms/sqs-key-arn
/shared/kms/ssm-key-arn
/shared/kms/elasticache-key-arn
/shared/ecr/fileflow-repository-url
/shared/ecr/fileflow-repository-arn
/shared/rds/prod/identifier
/shared/rds/prod/endpoint
/shared/rds/prod/security-group-id
/shared/rds/prod/master-secret-arn
```

---

## 다음 단계

Infrastructure 프로젝트 설정을 완료했습니다. 이제 Application 프로젝트에서 이 공유 리소스를 참조할 수 있습니다:

- **[4️⃣ Application 프로젝트 설정](hybrid-04-application-setup.md)**: SSM Parameters를 데이터 소스로 참조하고 Application 리소스 배포
- **[5️⃣ 배포 가이드](hybrid-05-deployment-guide.md)**: Terraform 검증, 배포, CI/CD 통합
- **[6️⃣ 모니터링 가이드](hybrid-06-monitoring-guide.md)**: CloudWatch, X-Ray, 메트릭, 알람 설정

---

**Last Updated**: 2025-10-22
