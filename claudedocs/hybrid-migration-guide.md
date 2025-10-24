# 하이브리드 인프라 관리 전환 가이드

## 📋 현재 상태 분석

### ✅ 이미 구현된 것들

Infrastructure 레포에 **SSM Parameter Store export가 이미 구현**되어 있습니다!

#### 1. Network Outputs (terraform/network/outputs.tf)
```hcl
# L69-112: SSM Parameter Store exports
resource "aws_ssm_parameter" "vpc-id" {
  name  = "/shared/network/vpc-id"
  value = aws_vpc.main.id
}

resource "aws_ssm_parameter" "public-subnet-ids" {
  name  = "/shared/network/public-subnet-ids"
  type  = "StringList"
  value = join(",", aws_subnet.public[*].id)
}

resource "aws_ssm_parameter" "private-subnet-ids" {
  name  = "/shared/network/private-subnet-ids"
  type  = "StringList"
  value = join(",", aws_subnet.private[*].id)
}
```

#### 2. KMS Outputs (terraform/kms/outputs.tf)
```hcl
# L137-255: SSM Parameter Store exports (8개 KMS 키)
- /shared/kms/cloudwatch-logs-key-arn
- /shared/kms/secrets-manager-key-arn
- /shared/kms/rds-key-arn
- /shared/kms/s3-key-arn
- /shared/kms/sqs-key-arn
- /shared/kms/ssm-key-arn
- /shared/kms/elasticache-key-arn
- /shared/kms/ecs-secrets-key-arn
```

#### 3. RDS Outputs (terraform/rds/outputs.tf)
```hcl
# L198-271: SSM Parameter Store exports
- /shared/rds/db-instance-id
- /shared/rds/db-instance-address
- /shared/rds/db-instance-port
- /shared/rds/db-security-group-id
- /shared/rds/master-password-secret-name
```

**결론**: **공유 인프라 → SSM Parameter Store export는 이미 완료!** ✅

---

## 🎯 하이브리드 전환 로드맵

### Phase 1: Infrastructure 레포 재구성 (이 레포)

#### Task 1.1: atlantis.yaml 수정
**목적**: FileFlow 관련 프로젝트 제거, 공유 인프라만 유지

**현재 상태**:
```yaml
# atlantis.yaml L149-156
projects:
  - name: ecr-fileflow-prod
    dir: terraform/ecr/fileflow
    # ...
```

**변경 후**:
```yaml
# ECR fileflow 프로젝트 제거
# 공유 인프라만 유지:
# - bootstrap, kms, network, rds, secrets
# - cloudtrail, logging, monitoring
# - route53, acm
# - atlantis (자체 서버)
```

**파일**: `/Users/sangwon-ryu/infrastructure/atlantis.yaml`

---

#### Task 1.2: terraform/ecr/fileflow/ 처리 결정

**Option A: 완전 이동**
- terraform/ecr/fileflow/ 삭제
- FileFlow 앱 레포로 완전 이동

**Option B: 하이브리드-라이트**
- terraform/ecr/fileflow/ 유지 (ECR은 중앙 관리)
- ECS, ALB, IAM만 앱 레포로 이동

**권장**: Option B (하이브리드-라이트)
- ECR은 보안 스캔, 정책 관리가 중요 → 중앙 관리
- ECS, ALB는 앱 팀이 자율 관리

---

#### Task 1.3: Governance Validators 재사용 패키지 생성

**목적**: 앱 레포에서 동일한 governance 검증 가능하도록

**현재 구조**:
```
scripts/validators/
├── check-tags.sh
├── check-encryption.sh
├── check-naming.sh
├── check-tfsec.sh
└── check-checkov.sh
```

**재사용 패키지 구조**:
```
scripts/governance-toolkit/
├── README.md                    # 사용 가이드
├── install.sh                   # 설치 스크립트
├── validators/
│   ├── check-tags.sh
│   ├── check-encryption.sh
│   ├── check-naming.sh
│   ├── check-tfsec.sh
│   └── check-checkov.sh
├── configs/
│   ├── .tfsec/config.yml
│   ├── .checkov.yml
│   └── policies/                # OPA policies
├── examples/
│   └── integrate-to-app-repo.sh
└── VERSION
```

**배포 방법**:
1. **Git Submodule** (권장)
   ```bash
   # FileFlow 앱 레포에서
   git submodule add https://github.com/org/infrastructure.git governance
   git submodule update --init --recursive
   ```

2. **NPM Package** (선택)
   ```bash
   npm install @ryuqqq/terraform-governance
   ```

3. **Manual Copy** (간단)
   ```bash
   curl -sSL https://raw.githubusercontent.com/org/infrastructure/main/scripts/install-governance.sh | bash
   ```

---

#### Task 1.4: 추가 SSM Parameters (선택 사항)

현재 누락된 공유 인프라 exports:

```hcl
# terraform/monitoring/outputs.tf에 추가 필요 (선택)
resource "aws_ssm_parameter" "sns-topic-arn" {
  name  = "/shared/monitoring/sns-topic-arn"
  value = aws_sns_topic.alerts.arn
}

# terraform/secrets/outputs.tf에 추가 필요 (선택)
resource "aws_ssm_parameter" "rotation-lambda-sg-id" {
  name  = "/shared/secrets/rotation-lambda-sg-id"
  value = aws_security_group.rotation-lambda[0].id
}
```

---

### Phase 2: FileFlow 앱 레포 설정

#### Task 2.1: 디렉토리 구조 생성

```
fileflow/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml         # 인프라 검증
│       ├── terraform-apply.yml        # 인프라 배포
│       ├── ci.yml                     # 앱 빌드/테스트
│       ├── build-and-push.yml         # ECR 푸시
│       └── deploy.yml                 # ECS 배포
├── app/                               # 애플리케이션 코드
│   ├── src/
│   ├── tests/
│   └── requirements.txt
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── terraform/                         # ⭐ 애플리케이션 인프라
│   ├── backend.tf                     # State backend
│   ├── versions.tf                    # Provider versions
│   ├── variables.tf                   # 변수 정의
│   ├── locals.tf                      # Local values
│   ├── data.tf                        # 공유 인프라 참조
│   ├── ecr.tf                         # ECR (Option A인 경우)
│   ├── ecs-cluster.tf                 # ECS 클러스터 (선택)
│   ├── ecs-task-definition.tf         # ECS 태스크 정의
│   ├── ecs-service.tf                 # ECS 서비스
│   ├── alb.tf                         # ALB, 타겟 그룹, 리스너
│   ├── security-groups.tf             # 보안 그룹
│   ├── iam.tf                         # IAM 역할, 정책
│   ├── cloudwatch.tf                  # 로그, 알람
│   └── outputs.tf                     # Outputs
├── scripts/
│   ├── deploy-ecs.sh                  # ECS 배포 스크립트
│   └── rollback.sh                    # 롤백 스크립트
├── atlantis.yaml                      # ⭐ Atlantis 설정
├── .gitignore
└── README.md
```

---

#### Task 2.2: Terraform Backend 설정

**파일**: `terraform/backend.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "prod-connectly"
    key            = "fileflow/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "prod-connectly-tf-lock"
    kms_key_id     = "alias/terraform-state"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = "FileFlow"
      Repository = "fileflow"
    }
  }
}
```

---

#### Task 2.3: 공유 인프라 참조 설정

**파일**: `terraform/data.tf`

```hcl
# ============================================================================
# 공유 인프라 참조 (SSM Parameter Store)
# ============================================================================

# Network Information
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "/shared/network/public-subnet-ids"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/shared/network/private-subnet-ids"
}

# KMS Keys
data "aws_ssm_parameter" "cloudwatch_logs_key_arn" {
  name = "/shared/kms/cloudwatch-logs-key-arn"
}

data "aws_ssm_parameter" "ecs_secrets_key_arn" {
  name = "/shared/kms/ecs-secrets-key-arn"
}

data "aws_ssm_parameter" "secrets_manager_key_arn" {
  name = "/shared/kms/secrets-manager-key-arn"
}

# RDS Information
data "aws_ssm_parameter" "db_instance_address" {
  name = "/shared/rds/db-instance-address"
}

data "aws_ssm_parameter" "db_instance_port" {
  name = "/shared/rds/db-instance-port"
}

data "aws_ssm_parameter" "db_security_group_id" {
  name = "/shared/rds/db-security-group-id"
}

data "aws_ssm_parameter" "master_password_secret_name" {
  name = "/shared/rds/master-password-secret-name"
}

# ============================================================================
# Locals for Easy Reference
# ============================================================================

locals {
  # Network
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  public_subnet_ids  = split(",", data.aws_ssm_parameter.public_subnet_ids.value)
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)

  # KMS
  cloudwatch_logs_kms_key_arn = data.aws_ssm_parameter.cloudwatch_logs_key_arn.value
  ecs_secrets_kms_key_arn     = data.aws_ssm_parameter.ecs_secrets_key_arn.value
  secrets_manager_kms_key_arn = data.aws_ssm_parameter.secrets_manager_key_arn.value

  # RDS
  db_address               = data.aws_ssm_parameter.db_instance_address.value
  db_port                  = data.aws_ssm_parameter.db_instance_port.value
  db_security_group_id     = data.aws_ssm_parameter.db_security_group_id.value
  db_credentials_secret    = data.aws_ssm_parameter.master_password_secret_name.value
}
```

---

#### Task 2.4: ECS 태스크 정의

**파일**: `terraform/ecs-task-definition.tf`

```hcl
# ============================================================================
# ECS Task Definition for FileFlow
# ============================================================================

resource "aws_ecs_task_definition" "fileflow" {
  family                   = "fileflow"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "fileflow"
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "APP_ENV"
          value = var.environment
        },
        {
          name  = "APP_PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "DB_HOST"
          value = local.db_address
        },
        {
          name  = "DB_PORT"
          value = local.db_port
        }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${local.db_credentials_secret}:password::"
        },
        {
          name      = "DB_USERNAME"
          valueFrom = "${local.db_credentials_secret}:username::"
        },
        {
          name      = "DB_NAME"
          valueFrom = "${local.db_credentials_secret}:dbname::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.fileflow.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-task-definition"
      Component = "ecs"
    }
  )
}
```

---

#### Task 2.5: ECS 서비스

**파일**: `terraform/ecs-service.tf`

```hcl
# ============================================================================
# ECS Service for FileFlow
# ============================================================================

resource "aws_ecs_service" "fileflow" {
  name            = "fileflow"
  cluster         = var.ecs_cluster_arn  # 공유 클러스터 또는 앱별 클러스터
  task_definition = aws_ecs_task_definition.fileflow.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  platform_version = "LATEST"

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.fileflow.arn
    container_name   = "fileflow"
    container_port   = var.container_port
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100

    deployment_circuit_breaker {
      enable   = true
      rollback = true
    }
  }

  deployment_controller {
    type = "ECS"  # or "CODE_DEPLOY" for blue/green
  }

  enable_execute_command = var.enable_ecs_exec

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-service"
      Component = "ecs"
    }
  )

  depends_on = [
    aws_lb_listener.fileflow
  ]
}

# Auto Scaling
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.fileflow.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "fileflow-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

---

#### Task 2.6: ALB 설정

**파일**: `terraform/alb.tf`

```hcl
# ============================================================================
# Application Load Balancer for FileFlow
# ============================================================================

resource "aws_lb" "fileflow" {
  name               = "fileflow-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-alb"
      Component = "alb"
    }
  )
}

resource "aws_lb_target_group" "fileflow" {
  name        = "fileflow-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-target-group"
      Component = "alb"
    }
  )
}

resource "aws_lb_listener" "fileflow" {
  load_balancer_arn = aws_lb.fileflow.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fileflow.arn
  }
}

# HTTP to HTTPS redirect
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.fileflow.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

---

#### Task 2.7: IAM 역할

**파일**: `terraform/iam.tf`

```hcl
# ============================================================================
# ECS Task Execution Role (AWS 관리 작업용)
# ============================================================================

resource "aws_iam_role" "ecs_execution" {
  name = "fileflow-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-ecs-execution-role"
      Component = "iam"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager 접근 권한
resource "aws_iam_role_policy" "secrets_access" {
  name = "fileflow-secrets-access"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${local.db_credentials_secret}*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = local.secrets_manager_kms_key_arn
      }
    ]
  })
}

# CloudWatch Logs 접근 권한
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "fileflow-cloudwatch-logs"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.fileflow.arn}:*"
      }
    ]
  })
}

# ============================================================================
# ECS Task Role (컨테이너 내부 애플리케이션용)
# ============================================================================

resource "aws_iam_role" "ecs_task" {
  name = "fileflow-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-ecs-task-role"
      Component = "iam"
    }
  )
}

# 애플리케이션별 권한 (예: S3, SQS 등)
resource "aws_iam_role_policy" "app_permissions" {
  name = "fileflow-app-permissions"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::fileflow-uploads/*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
```

---

#### Task 2.8: Security Groups

**파일**: `terraform/security-groups.tf`

```hcl
# ============================================================================
# ALB Security Group
# ============================================================================

resource "aws_security_group" "alb" {
  name        = "fileflow-alb-sg"
  description = "Security group for FileFlow ALB"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from Internet (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-alb-sg"
      Component = "security-group"
    }
  )
}

# ============================================================================
# ECS Tasks Security Group
# ============================================================================

resource "aws_security_group" "ecs_tasks" {
  name        = "fileflow-ecs-tasks-sg"
  description = "Security group for FileFlow ECS tasks"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-ecs-tasks-sg"
      Component = "security-group"
    }
  )
}

# ============================================================================
# RDS Access Rule (기존 RDS SG에 추가 규칙 필요)
# ============================================================================

# FileFlow ECS tasks가 RDS에 접근할 수 있도록 허용
resource "aws_security_group_rule" "rds_from_fileflow" {
  type                     = "ingress"
  from_port                = tonumber(local.db_port)
  to_port                  = tonumber(local.db_port)
  protocol                 = "tcp"
  security_group_id        = local.db_security_group_id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "Allow FileFlow ECS tasks to access RDS"
}
```

---

#### Task 2.9: CloudWatch Logs

**파일**: `terraform/cloudwatch.tf`

```hcl
# ============================================================================
# CloudWatch Log Group
# ============================================================================

resource "aws_cloudwatch_log_group" "fileflow" {
  name              = "/ecs/fileflow"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.cloudwatch_logs_kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-logs"
      Component = "cloudwatch"
    }
  )
}

# ============================================================================
# CloudWatch Alarms
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  alarm_name          = "fileflow-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "FileFlow ECS service CPU utilization is too high"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.fileflow.name
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-cpu-alarm"
      Component = "cloudwatch"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  alarm_name          = "fileflow-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "FileFlow ECS service memory utilization is too high"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.fileflow.name
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-memory-alarm"
      Component = "cloudwatch"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "target_response_time" {
  alarm_name          = "fileflow-slow-response"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "FileFlow ALB response time is too high"

  dimensions = {
    LoadBalancer = aws_lb.fileflow.arn_suffix
    TargetGroup  = aws_lb_target_group.fileflow.arn_suffix
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "fileflow-response-time-alarm"
      Component = "cloudwatch"
    }
  )
}
```

---

#### Task 2.10: Variables

**파일**: `terraform/variables.tf`

```hcl
# ============================================================================
# General Variables
# ============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "service" {
  description = "Service name"
  type        = string
  default     = "fileflow"
}

# ============================================================================
# ECS Variables
# ============================================================================

variable "ecs_cluster_arn" {
  description = "ECS cluster ARN (shared or app-specific)"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "task_cpu" {
  description = "ECS task CPU units (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "ECS task memory in MB (512, 1024, 2048, 4096, 8192, 16384, 30720)"
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of ECS tasks for autoscaling"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks for autoscaling"
  type        = number
  default     = 10
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

variable "enable_ecs_exec" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

# ============================================================================
# ECR Variables
# ============================================================================

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

# ============================================================================
# ALB Variables
# ============================================================================

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = true
}

# ============================================================================
# CloudWatch Variables
# ============================================================================

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 30
}

# ============================================================================
# Tags Variables
# ============================================================================

variable "owner" {
  description = "Team or person responsible"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}
```

---

#### Task 2.11: Locals

**파일**: `terraform/locals.tf`

```hcl
# ============================================================================
# Local Values
# ============================================================================

locals {
  # Common tags (required by governance)
  common_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Service     = var.service
    Lifecycle   = "production"
    DataClass   = "confidential"
    ManagedBy   = "Terraform"
    Repository  = "fileflow"
    Project     = "FileFlow"
  }

  # Environment-specific values
  is_prod = var.environment == "prod"
}
```

---

#### Task 2.12: Outputs

**파일**: `terraform/outputs.tf`

```hcl
# ============================================================================
# ECS Outputs
# ============================================================================

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.fileflow.name
}

output "ecs_service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.fileflow.id
}

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.fileflow.arn
}

# ============================================================================
# ALB Outputs
# ============================================================================

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.fileflow.dns_name
}

output "alb_zone_id" {
  description = "ALB Route53 zone ID"
  value       = aws_lb.fileflow.zone_id
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = aws_lb_target_group.fileflow.arn
}

# ============================================================================
# Security Group Outputs
# ============================================================================

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "ecs_tasks_security_group_id" {
  description = "ECS tasks security group ID"
  value       = aws_security_group.ecs_tasks.id
}

# ============================================================================
# CloudWatch Outputs
# ============================================================================

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.fileflow.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.fileflow.arn
}
```

---

#### Task 2.13: Atlantis 설정

**파일**: `atlantis.yaml`

```yaml
version: 3

automerge: false
delete_source_branch_on_merge: false
parallel_plan: false
parallel_apply: false

projects:
  - name: fileflow-infrastructure-prod
    dir: terraform
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default

workflows:
  default:
    plan:
      steps:
        - env:
            name: TF_PLUGIN_CACHE_DIR
            value: ""
        - init:
            extra_args:
              - "-upgrade"
        - plan
    apply:
      steps:
        - apply
```

---

#### Task 2.14: GitHub Actions Workflows

##### **terraform-plan.yml**

```yaml
name: Terraform Plan

on:
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-*.yml'

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-2

      - name: Terraform Init
        working-directory: terraform
        run: terraform init

      - name: Terraform Format Check
        working-directory: terraform
        run: terraform fmt -check -recursive

      - name: Terraform Validate
        working-directory: terraform
        run: terraform validate

      - name: Terraform Plan
        working-directory: terraform
        run: terraform plan -out=tfplan

      # Governance checks (from submodule)
      - name: Run Governance Validators
        run: |
          ./governance/validators/check-tags.sh
          ./governance/validators/check-encryption.sh
          ./governance/validators/check-tfsec.sh
```

##### **terraform-apply.yml**

```yaml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  terraform-apply:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0
          terraform_wrapper: false

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-2

      - name: Terraform Init
        working-directory: terraform
        run: terraform init

      - name: Terraform Apply
        working-directory: terraform
        run: terraform apply -auto-approve
```

---

### Phase 3: State 마이그레이션 (ECR FileFlow)

#### Task 3.1: State 마이그레이션 스크립트

**파일**: `scripts/migrate-ecr-state.sh`

```bash
#!/bin/bash
set -euo pipefail

# ============================================================================
# ECR FileFlow State Migration Script
# ============================================================================
# Infrastructure 레포에서 FileFlow 앱 레포로 ECR state 마이그레이션
#
# Usage:
#   ./scripts/migrate-ecr-state.sh
#
# Prerequisites:
#   - AWS credentials configured
#   - Terraform 1.6+ installed
#   - Access to both repositories
# ============================================================================

echo "🔄 Starting ECR FileFlow state migration..."

# Variables
INFRA_REPO="/Users/sangwon-ryu/infrastructure"
APP_REPO="/path/to/fileflow"  # Update this
ECR_MODULE="terraform/ecr/fileflow"
STATE_BUCKET="prod-connectly"
INFRA_STATE_KEY="ecr/fileflow/terraform.tfstate"
APP_STATE_KEY="fileflow/terraform.tfstate"

# Step 1: Export resources from Infrastructure repo
echo "📤 Step 1: Exporting ECR resources from Infrastructure repo..."
cd "${INFRA_REPO}/${ECR_MODULE}"

terraform state list > /tmp/ecr-fileflow-resources.txt
echo "Found resources:"
cat /tmp/ecr-fileflow-resources.txt

# Export state to local file
terraform state pull > /tmp/ecr-fileflow-state.json
echo "✅ State exported to /tmp/ecr-fileflow-state.json"

# Step 2: Remove resources from Infrastructure repo
echo "🗑️  Step 2: Removing ECR resources from Infrastructure repo state..."
while IFS= read -r resource; do
  echo "Removing: $resource"
  terraform state rm "$resource" || echo "⚠️  Failed to remove $resource"
done < /tmp/ecr-fileflow-resources.txt

# Step 3: Import to FileFlow app repo
echo "📥 Step 3: Importing ECR resources to FileFlow app repo..."
cd "${APP_REPO}/terraform"

# Initialize if not done
terraform init

# Import each resource
# Example: aws_ecr_repository.fileflow
ECR_REPO_NAME=$(aws ecr describe-repositories \
  --repository-names fileflow \
  --query 'repositories[0].repositoryName' \
  --output text)

terraform import aws_ecr_repository.fileflow "$ECR_REPO_NAME"

echo "✅ ECR state migration completed!"
echo ""
echo "📋 Next steps:"
echo "1. Verify terraform plan in FileFlow app repo"
echo "2. Commit changes to both repositories"
echo "3. Update atlantis.yaml in Infrastructure repo"
echo "4. Update CI/CD pipelines"
```

---

### Phase 4: 검증 및 롤아웃

#### Checklist

##### Infrastructure 레포
- [ ] `atlantis.yaml` 수정 (ECR fileflow 프로젝트 제거)
- [ ] SSM Parameters 확인 (이미 완료 ✅)
- [ ] Governance validators 모듈화
- [ ] GitHub Actions 워크플로우 업데이트
- [ ] README 업데이트

##### FileFlow 앱 레포
- [ ] 디렉토리 구조 생성
- [ ] Terraform 코드 작성 (backend, data, ecs, alb, iam, etc.)
- [ ] `atlantis.yaml` 생성
- [ ] GitHub Actions 워크플로우 설정
- [ ] ECR state 마이그레이션 (선택)
- [ ] 테스트 환경 배포
- [ ] 프로덕션 배포

##### 검증
- [ ] Terraform plan 성공 (앱 레포)
- [ ] Atlantis autoplan 동작 확인 (앱 레포)
- [ ] Governance validators 실행 성공
- [ ] ECS 서비스 정상 배포
- [ ] ALB 헬스 체크 통과
- [ ] RDS 연결 확인
- [ ] CloudWatch 로그 확인
- [ ] 알람 설정 확인

---

## 📝 요약

### 필요한 작업 (Infrastructure 레포)

1. **atlantis.yaml 수정**
   - ECR fileflow 프로젝트 제거
   - 공유 인프라만 유지

2. **Governance validators 모듈화** (선택)
   - `scripts/governance-toolkit/` 생성
   - Git submodule 또는 package로 배포

3. **추가 SSM Parameters** (선택)
   - Monitoring, Secrets 등 필요한 것만

### 필요한 작업 (FileFlow 앱 레포)

1. **Terraform 인프라 코드 작성**
   - backend, data, ecs, alb, iam, security-groups, cloudwatch
   - 총 10개 파일

2. **atlantis.yaml 생성**
   - 앱 인프라 프로젝트 등록

3. **GitHub Actions 워크플로우**
   - terraform-plan.yml
   - terraform-apply.yml
   - ci.yml, build-and-push.yml, deploy.yml

4. **State 마이그레이션** (ECR, 선택)
   - Infrastructure → FileFlow 앱 레포

### 장점

✅ 애플리케이션 팀 완전 자율성
✅ 앱 코드와 인프라가 같은 레포
✅ 병렬 작업 가능
✅ GitOps 친화적

### 단점

⚠️ 초기 설정 복잡도
⚠️ 의존성 관리 필요
⚠️ Governance 중복 적용

---

## 🚀 시작 방법

### 1단계: Infrastructure 레포 준비
```bash
cd /Users/sangwon-ryu/infrastructure

# atlantis.yaml 백업
cp atlantis.yaml atlantis.yaml.backup

# atlantis.yaml 수정 (ECR fileflow 제거)
# vim atlantis.yaml

# Governance toolkit 생성 (선택)
# mkdir -p scripts/governance-toolkit
```

### 2단계: FileFlow 앱 레포 설정
```bash
cd /path/to/fileflow

# 디렉토리 구조 생성
mkdir -p terraform .github/workflows scripts

# Terraform 파일 생성
# (이 가이드의 코드 복사)

# Git submodule 추가 (governance)
git submodule add https://github.com/org/infrastructure.git governance
```

### 3단계: 테스트 배포
```bash
# FileFlow 앱 레포에서
cd terraform
terraform init
terraform plan
terraform apply

# ECS 서비스 확인
aws ecs describe-services --cluster prod-cluster --services fileflow
```

다음 단계를 진행할까요? 어떤 부분부터 시작하시겠어요?
