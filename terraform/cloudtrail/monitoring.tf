# Security Event Monitoring and Alerts
# EventBridge rules and SNS notifications for critical security events

# SNS Topic for Security Alerts
resource "aws_sns_topic" "security_alerts" {
  count             = var.enable_security_alerts ? 1 : 0
  name              = local.security_alerts_topic_name
  display_name      = "CloudTrail Security Alerts"
  kms_master_key_id = aws_kms_key.cloudtrail.id

  tags = merge(
    local.required_tags,
    {
      Name      = local.security_alerts_topic_name
      Component = "security-monitoring"
    }
  )
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "security_alerts" {
  count = var.enable_security_alerts ? 1 : 0
  arn   = aws_sns_topic.security_alerts[0].arn

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
        Resource = aws_sns_topic.security_alerts[0].arn
      }
    ]
  })
}

# SNS Email Subscription (if email provided)
resource "aws_sns_topic_subscription" "security_alerts_email" {
  count     = var.enable_security_alerts && var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EventBridge Rule: Root Account Usage
resource "aws_cloudwatch_event_rule" "root_account_usage" {
  count       = var.enable_security_alerts ? 1 : 0
  name        = "cloudtrail-root-account-usage"
  description = "Alert when root account is used"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      userIdentity = {
        type = ["Root"]
      }
    }
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "cloudtrail-root-account-usage"
      Component = "security-monitoring"
    }
  )
}

resource "aws_cloudwatch_event_target" "root_account_usage" {
  count     = var.enable_security_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.root_account_usage[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts[0].arn

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
resource "aws_cloudwatch_event_rule" "unauthorized_api_calls" {
  count       = var.enable_security_alerts ? 1 : 0
  name        = "cloudtrail-unauthorized-api-calls"
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

  tags = merge(
    local.required_tags,
    {
      Name      = "cloudtrail-unauthorized-api-calls"
      Component = "security-monitoring"
    }
  )
}

resource "aws_cloudwatch_event_target" "unauthorized_api_calls" {
  count     = var.enable_security_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.unauthorized_api_calls[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts[0].arn

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
resource "aws_cloudwatch_event_rule" "iam_policy_changes" {
  count       = var.enable_security_alerts ? 1 : 0
  name        = "cloudtrail-iam-policy-changes"
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

  tags = merge(
    local.required_tags,
    {
      Name      = "cloudtrail-iam-policy-changes"
      Component = "security-monitoring"
    }
  )
}

resource "aws_cloudwatch_event_target" "iam_policy_changes" {
  count     = var.enable_security_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.iam_policy_changes[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts[0].arn

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
resource "aws_cloudwatch_event_rule" "console_login_failures" {
  count       = var.enable_security_alerts ? 1 : 0
  name        = "cloudtrail-console-login-failures"
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

  tags = merge(
    local.required_tags,
    {
      Name      = "cloudtrail-console-login-failures"
      Component = "security-monitoring"
    }
  )
}

resource "aws_cloudwatch_event_target" "console_login_failures" {
  count     = var.enable_security_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.console_login_failures[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts[0].arn

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
resource "aws_cloudwatch_event_rule" "security_group_changes" {
  count       = var.enable_security_alerts ? 1 : 0
  name        = "cloudtrail-security-group-changes"
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

  tags = merge(
    local.required_tags,
    {
      Name      = "cloudtrail-security-group-changes"
      Component = "security-monitoring"
    }
  )
}

resource "aws_cloudwatch_event_target" "security_group_changes" {
  count     = var.enable_security_alerts ? 1 : 0
  rule      = aws_cloudwatch_event_rule.security_group_changes[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts[0].arn

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
