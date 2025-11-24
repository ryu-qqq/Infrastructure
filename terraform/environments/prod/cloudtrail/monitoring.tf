# Security Event Monitoring and Alerts
# EventBridge rules and SNS notifications for critical security events

# SNS Topic for Security Alerts
resource "aws_sns_topic" "security-alerts" {
  count             = var.enable_security_alerts ? 1 : 0
  name              = local.security_alerts_topic_name
  display_name      = "CloudTrail Security Alerts"
  kms_master_key_id = aws_kms_key.cloudtrail.id

  tags = {
    Name        = local.security_alerts_topic_name
    Component   = "security-monitoring"
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "security-alerts" {
  count = var.enable_security_alerts ? 1 : 0
  arn   = aws_sns_topic.security-alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToPublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security-alerts[0].arn
      }
    ]
  })
}

# SNS Email Subscription (if email provided)
resource "aws_sns_topic_subscription" "security-alerts-email" {
  count     = var.enable_security_alerts && var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security-alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EventBridge Rule: Root Account Usage
resource "aws_cloudwatch_event_rule" "root-account-usage" {
  count       = var.enable_security_alerts ? 1 : 0
  name        = "${var.cloudtrail_name}-root-account-usage"
  description = "Alert when root account is used"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      userIdentity = {
        type = ["Root"]
      }
    }
  })

  tags = {
    Name        = "cloudtrail-root-account-usage"
    Component   = "security-monitoring"
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "root-account-usage" {
  count     = var.enable_security_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.root-account-usage[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security-alerts[0].arn

  input_transformer {
    input_paths = {
      time      = "$.detail.eventTime"
      user      = "$.detail.userIdentity.principalId"
      event     = "$.detail.eventName"
      sourceIP  = "$.detail.sourceIPAddress"
      userAgent = "$.detail.userAgent"
    }
    input_template = "\"🚨 ROOT ACCOUNT USAGE DETECTED\\n\\nTime: <time>\\nUser: <user>\\nEvent: <event>\\nSource IP: <sourceIP>\\nUser Agent: <userAgent>\\n\\nAction Required: Investigate immediately!\""
  }
}

# EventBridge Rule: Unauthorized API Calls
resource "aws_cloudwatch_event_rule" "unauthorized-api-calls" {
  count       = var.enable_security_alerts ? 1 : 0
  name        = "${var.cloudtrail_name}-unauthorized-api-calls"
  description = "Alert on unauthorized API calls"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      errorCode = [
        "UnauthorizedOperation",
        "AccessDenied"
      ]
    }
  })

  tags = {
    Name        = "cloudtrail-unauthorized-api-calls"
    Component   = "security-monitoring"
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "unauthorized-api-calls" {
  count     = var.enable_security_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.unauthorized-api-calls[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security-alerts[0].arn

  input_transformer {
    input_paths = {
      time      = "$.detail.eventTime"
      user      = "$.detail.userIdentity.arn"
      event     = "$.detail.eventName"
      sourceIP  = "$.detail.sourceIPAddress"
      errorCode = "$.detail.errorCode"
      errorMsg  = "$.detail.errorMessage"
    }
    input_template = "\"⚠️ UNAUTHORIZED API CALL\\n\\nTime: <time>\\nUser: <user>\\nEvent: <event>\\nSource IP: <sourceIP>\\nError Code: <errorCode>\\nError Message: <errorMsg>\""
  }
}

# EventBridge Rule: IAM Policy Changes
resource "aws_cloudwatch_event_rule" "iam-policy-changes" {
  count       = var.enable_security_alerts ? 1 : 0
  name        = "${var.cloudtrail_name}-iam-policy-changes"
  description = "Alert on IAM policy changes"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["iam.amazonaws.com"]
      eventName = [
        "PutUserPolicy",
        "PutGroupPolicy",
        "PutRolePolicy",
        "CreatePolicy",
        "DeletePolicy",
        "CreatePolicyVersion",
        "AttachUserPolicy",
        "AttachGroupPolicy",
        "AttachRolePolicy",
        "DetachUserPolicy",
        "DetachGroupPolicy",
        "DetachRolePolicy"
      ]
    }
  })

  tags = {
    Name        = "cloudtrail-iam-policy-changes"
    Component   = "security-monitoring"
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "iam-policy-changes" {
  count     = var.enable_security_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.iam-policy-changes[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security-alerts[0].arn

  input_transformer {
    input_paths = {
      time     = "$.detail.eventTime"
      user     = "$.detail.userIdentity.arn"
      event    = "$.detail.eventName"
      sourceIP = "$.detail.sourceIPAddress"
    }
    input_template = "\"🔐 IAM POLICY CHANGE\\n\\nTime: <time>\\nUser: <user>\\nEvent: <event>\\nSource IP: <sourceIP>\\n\\nReview IAM policy changes in CloudTrail.\""
  }
}

# EventBridge Rule: Console Login Failures
resource "aws_cloudwatch_event_rule" "console-login-failures" {
  count       = var.enable_security_alerts ? 1 : 0
  name        = "${var.cloudtrail_name}-console-login-failures"
  description = "Alert on console login failures"

  event_pattern = jsonencode({
    detail-type = ["AWS Console Sign In via CloudTrail"]
    detail = {
      eventName = ["ConsoleLogin"]
      responseElements = {
        ConsoleLogin = ["Failure"]
      }
    }
  })

  tags = {
    Name        = "cloudtrail-console-login-failures"
    Component   = "security-monitoring"
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "console-login-failures" {
  count     = var.enable_security_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.console-login-failures[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security-alerts[0].arn

  input_transformer {
    input_paths = {
      time      = "$.detail.eventTime"
      user      = "$.detail.userIdentity.principalId"
      sourceIP  = "$.detail.sourceIPAddress"
      userAgent = "$.detail.userAgent"
    }
    input_template = "\"🔒 CONSOLE LOGIN FAILURE\\n\\nTime: <time>\\nUser: <user>\\nSource IP: <sourceIP>\\nUser Agent: <userAgent>\\n\\nMultiple failures may indicate brute force attempt.\""
  }
}

# EventBridge Rule: Security Group Changes
resource "aws_cloudwatch_event_rule" "security-group-changes" {
  count       = var.enable_security_alerts ? 1 : 0
  name        = "${var.cloudtrail_name}-security-group-changes"
  description = "Alert on security group changes"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ec2.amazonaws.com"]
      eventName = [
        "AuthorizeSecurityGroupIngress",
        "AuthorizeSecurityGroupEgress",
        "RevokeSecurityGroupIngress",
        "RevokeSecurityGroupEgress",
        "CreateSecurityGroup",
        "DeleteSecurityGroup"
      ]
    }
  })

  tags = {
    Name        = "cloudtrail-security-group-changes"
    Component   = "security-monitoring"
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "security-group-changes" {
  count     = var.enable_security_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.security-group-changes[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security-alerts[0].arn

  input_transformer {
    input_paths = {
      time   = "$.detail.eventTime"
      user   = "$.detail.userIdentity.arn"
      event  = "$.detail.eventName"
      region = "$.detail.awsRegion"
    }
    input_template = "\"🛡️ SECURITY GROUP CHANGE\\n\\nTime: <time>\\nUser: <user>\\nEvent: <event>\\nRegion: <region>\\n\\nReview security group changes in AWS Console.\""
  }
}
