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
    values = ["Private"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "tag:Type"
    values = ["Public"]
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

# Read RDS identifiers from SSM Parameter Store (exported by RDS module)
data "aws_ssm_parameter" "db-instance-id" {
  name = "/shared/rds/db-instance-id"
}

data "aws_ssm_parameter" "master-password-secret-name" {
  name = "/shared/rds/master-password-secret-name"
}

data "aws_db_instance" "main" {
  db_instance_identifier = data.aws_ssm_parameter.db-instance-id.value
}

data "aws_secretsmanager_secret" "db-master-password" {
  name = data.aws_ssm_parameter.master-password-secret-name.value
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
