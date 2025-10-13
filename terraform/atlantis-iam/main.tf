# ============================================
# Atlantis IAM AssumeRole 권한 구조
# TASK 1-2: IAM AssumeRole 권한 구조 설계
# ============================================

# --------------------------------------------
# 1. Atlantis ECS Task Role
# --------------------------------------------

# Atlantis Task Role (ECS에서 실행되는 Atlantis 서비스가 사용)
resource "aws_iam_role" "atlantis_task_role" {
  name               = var.atlantis_task_role_name
  description        = "IAM Role for Atlantis ECS Task to assume Target Roles"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json

  tags = merge(
    local.required_tags,
    {
      Name = var.atlantis_task_role_name
    }
  )
}

# ECS 태스크가 이 Role을 Assume할 수 있도록 Trust Policy 설정
data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Atlantis Task Role에 AssumeRole 권한 부여
resource "aws_iam_role_policy" "atlantis_assume_role_policy" {
  name   = "atlantis-assume-role-policy"
  role   = aws_iam_role.atlantis_task_role.id
  policy = data.aws_iam_policy_document.atlantis_assume_role_policy.json
}

data "aws_iam_policy_document" "atlantis_assume_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      aws_iam_role.atlantis_target_prod.arn,
    ]
  }
}

# --------------------------------------------
# 2. Target Role (PROD only)
# --------------------------------------------

# PROD 환경 Target Role
resource "aws_iam_role" "atlantis_target_prod" {
  name               = "atlantis-target-prod"
  description        = "Target Role for Atlantis to manage prod environment resources"
  assume_role_policy = data.aws_iam_policy_document.target_role_trust_policy.json

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-target-prod"
      Environment = "prod"
    }
  )
}

# Target Roles의 Trust Policy (Atlantis Task Role만 Assume 가능)
data "aws_iam_policy_document" "target_role_trust_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.atlantis_task_role.arn]
    }
    actions = ["sts:AssumeRole"]
  }
}

# --------------------------------------------
# 3. Target Role 권한 정책 (최소 권한 원칙)
# --------------------------------------------

# Terraform 실행에 필요한 기본 권한 정책
data "aws_iam_policy_document" "terraform_base_permissions" {
  # ECS 권한
  statement {
    sid    = "ECSManagement"
    effect = "Allow"
    actions = [
      "ecs:CreateCluster",
      "ecs:DeleteCluster",
      "ecs:DescribeClusters",
      "ecs:CreateService",
      "ecs:UpdateService",
      "ecs:DeleteService",
      "ecs:DescribeServices",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTaskDefinitions",
      "ecs:TagResource",
      "ecs:UntagResource",
    ]
    resources = ["*"]
  }

  # RDS 권한
  statement {
    sid    = "RDSManagement"
    effect = "Allow"
    actions = [
      "rds:CreateDBInstance",
      "rds:ModifyDBInstance",
      "rds:DeleteDBInstance",
      "rds:DescribeDBInstances",
      "rds:CreateDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:DescribeDBSubnetGroups",
      "rds:CreateDBParameterGroup",
      "rds:ModifyDBParameterGroup",
      "rds:DeleteDBParameterGroup",
      "rds:DescribeDBParameterGroups",
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource",
      "rds:ListTagsForResource",
    ]
    resources = ["*"]
  }

  # ALB 권한
  statement {
    sid    = "ALBManagement"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = ["*"]
  }

  # VPC 권한
  statement {
    sid    = "VPCManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:DescribeVpcs",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:DescribeSubnets",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeSecurityGroups",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeTags",
    ]
    resources = ["*"]
  }

  # IAM 권한 (제한적)
  statement {
    sid    = "IAMManagement"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
    ]
    resources = [
      "arn:aws:iam::*:role/*-ecs-task-role",
      "arn:aws:iam::*:role/*-ecs-execution-role",
    ]
  }

  # CloudWatch Logs 권한
  statement {
    sid    = "CloudWatchLogsManagement"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
    ]
    resources = ["*"]
  }

  # Secrets Manager 권한 (읽기 전용)
  statement {
    sid    = "SecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = ["*"]
  }
}

# PROD 환경 정책 연결
resource "aws_iam_role_policy" "atlantis_target_prod_policy" {
  name   = "terraform-base-permissions"
  role   = aws_iam_role.atlantis_target_prod.id
  policy = data.aws_iam_policy_document.terraform_base_permissions.json
}
