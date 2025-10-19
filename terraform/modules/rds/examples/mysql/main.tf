# MySQL RDS 인스턴스 예제
#
# 이 예제는 운영 환경에서 사용 가능한 MySQL RDS 인스턴스를 배포하는 방법을 보여줍니다.
# Multi-AZ, 자동 백업, KMS 암호화, Performance Insights 등의 기능을 포함합니다.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 기존 리소스 조회
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "database" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Type = "private"
  }
}

# 공통 태그 모듈
module "common_tags" {
  source = "../../../common-tags"

  environment = var.environment
  service     = var.service_name
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}

# KMS 키 (RDS 암호화용)
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS MySQL encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-rds-${var.environment}"
    }
  )
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.service_name}-rds-${var.environment}"
  target_key_id = aws_kms_key.rds.key_id
}

# DB Subnet Group은 RDS 모듈 내부에서 자동 생성됨

# RDS용 보안 그룹
resource "aws_security_group" "rds" {
  name        = "${var.service_name}-rds-${var.environment}"
  description = "Security group for RDS MySQL instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from application layer"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-rds-${var.environment}"
    }
  )
}

# DB Parameter Group은 이 예제에서는 사용하지 않음
# RDS 모듈의 기본 Parameter Group 사용
# 커스텀 파라미터가 필요한 경우, RDS 모듈에 parameter_group 기능 추가 필요

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.service_name}-rds-monitoring-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-rds-monitoring-${var.environment}"
    }
  )
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Secrets Manager에 초기 비밀번호 저장
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.service_name}-db-password-${var.environment}"
  description             = "RDS MySQL master password"
  recovery_window_in_days = 7

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-db-password-${var.environment}"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.master_password
}

# RDS MySQL 인스턴스 모듈
module "rds_mysql" {
  source = "../../"

  # 기본 설정
  identifier     = "${var.service_name}-${var.environment}"
  engine         = "mysql"
  engine_version = var.mysql_version
  instance_class = var.instance_class

  # 스토리지 설정
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  # 데이터베이스 설정
  db_name         = var.database_name
  master_username = var.master_username
  master_password = var.master_password

  # 네트워크 설정
  subnet_ids          = data.aws_subnets.database.ids
  security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible = false
  multi_az            = var.enable_multi_az

  # 백업 설정
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00" # UTC 기준
  maintenance_window      = "mon:04:00-mon:05:00"

  # 스냅샷 설정
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.service_name}-final-snapshot-${var.environment}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  copy_tags_to_snapshot     = true

  # Parameter Group은 모듈 내부에서 default로 생성됨
  # 커스텀 파라미터가 필요하면 모듈에 추가 기능 필요

  # 모니터링 설정
  enabled_cloudwatch_logs_exports       = ["error", "general", "slowquery"]
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # 삭제 방지
  deletion_protection = var.enable_deletion_protection

  # 태그
  common_tags = module.common_tags.tags
}

# CloudWatch 알람 - CPU 사용률
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  alarm_name          = "${var.service_name}-rds-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = module.rds_mysql.db_instance_id
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-rds-cpu-${var.environment}"
    }
  )
}

# CloudWatch 알람 - 스토리지 사용량
resource "aws_cloudwatch_metric_alarm" "storage_space" {
  alarm_name          = "${var.service_name}-rds-storage-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000000000" # 5GB
  alarm_description   = "RDS free storage space is low"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = module.rds_mysql.db_instance_id
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-rds-storage-${var.environment}"
    }
  )
}

# CloudWatch 알람 - 연결 수
resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "${var.service_name}-rds-connections-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.max_connections * 0.8 # max_connections의 80%
  alarm_description   = "RDS database connections are too high"
  alarm_actions       = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = module.rds_mysql.db_instance_id
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-rds-connections-${var.environment}"
    }
  )
}
