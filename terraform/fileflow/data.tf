# Data Sources for Cross-Stack References

# ============================================================================
# Network Data Sources
# ============================================================================

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["prod-server-vpc"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Type"
    values = ["public"]
  }
}

# ============================================================================
# KMS Data Sources
# ============================================================================

data "aws_kms_key" "cloudwatch-logs" {
  key_id = "alias/cloudwatch-logs"
}

data "aws_kms_key" "secrets-manager" {
  key_id = "alias/secrets-manager"
}

data "aws_kms_key" "ecs-secrets" {
  key_id = "alias/ecs-secrets"
}

# ============================================================================
# RDS Data Sources
# ============================================================================

data "aws_db_instance" "main" {
  db_instance_identifier = "prod-server"
}

data "aws_secretsmanager_secret" "db-master-password" {
  name = "rds/prod-server/master-credentials"
}

data "aws_secretsmanager_secret_version" "db-master-password" {
  secret_id = data.aws_secretsmanager_secret.db-master-password.id
}

# ============================================================================
# Local Variables from Data Sources
# ============================================================================

locals {
  vpc_id              = data.aws_vpc.main.id
  private_subnet_ids  = data.aws_subnets.private.ids
  public_subnet_ids   = data.aws_subnets.public.ids

  cloudwatch_logs_key_arn  = data.aws_kms_key.cloudwatch-logs.arn
  secrets_manager_key_arn  = data.aws_kms_key.secrets-manager.arn
  ecs_secrets_key_arn      = data.aws_kms_key.ecs-secrets.arn

  # RDS connection details
  rds_endpoint = data.aws_db_instance.main.address
  rds_port     = data.aws_db_instance.main.port

  # Parse DB credentials from secret
  db_credentials = jsondecode(data.aws_secretsmanager_secret_version.db-master-password.secret_string)
  db_username    = local.db_credentials.username
}
