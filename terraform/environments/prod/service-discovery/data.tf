# Data Sources for Service Discovery

# VPC ID from SSM Parameter Store (Cross-Stack Reference)
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
}
