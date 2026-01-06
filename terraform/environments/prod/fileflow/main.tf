locals {
  required_tags = {
    Owner       = "team-fileflow"
    CostCenter  = "cloudwatch-logs"
    Environment = "prod"
    Lifecycle   = "production"
    DataClass   = "high"
    Service     = "fileflow"
  }
}

resource "aws_iam_role_policy" "atlantis_ecs_task_policy" {
  name   = "atlantis-ecs-task-policy"
  role   = "atlantis-ecs-task-prod"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect"   : "Allow",
        "Action"   : [
          "logs:PutSubscriptionFilter",
          "logs:DeleteSubscriptionFilter",
          "logs:DescribeSubscriptionFilters"
        ],
        "Resource" : "arn:aws:logs:ap-northeast-2:646886795421:log-group:*"
      },
      {
        "Effect"   : "Allow",
        "Action"   : "iam:PassRole",
        "Resource" : "arn:aws:iam::646886795421:role/*-log-delivery-role"
      }
    ]
  })

  tags = merge(local.required_tags, {
    Name = "atlantis-ecs-task-policy"
  })
}