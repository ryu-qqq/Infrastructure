# IAM User for Marketplace Service (Local Development & Testing)
# Provides access to Amazon Textract (OCR) and SES (Email)

resource "aws_iam_user" "marketplace" {
  name = "marketplace-service-user"
  path = "/service/"

  tags = merge(
    local.required_tags,
    {
      Name        = "marketplace-service-user"
      Description = "IAM user for Marketplace service - Textract and SES access"
      Component   = "iam-user"
    }
  )
}

# Access Key for programmatic access
resource "aws_iam_access_key" "marketplace" {
  user = aws_iam_user.marketplace.name
}

# IAM Policy for Amazon Textract (OCR)
resource "aws_iam_policy" "marketplace_textract" {
  name        = "marketplace-textract-policy"
  description = "Full access to Amazon Textract for OCR operations"
  path        = "/service/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TextractFullAccess"
        Effect = "Allow"
        Action = [
          "textract:AnalyzeDocument",
          "textract:AnalyzeExpense",
          "textract:AnalyzeID",
          "textract:DetectDocumentText",
          "textract:GetDocumentAnalysis",
          "textract:GetDocumentTextDetection",
          "textract:GetExpenseAnalysis",
          "textract:StartDocumentAnalysis",
          "textract:StartDocumentTextDetection",
          "textract:StartExpenseAnalysis",
          "textract:GetLendingAnalysis",
          "textract:GetLendingAnalysisSummary",
          "textract:StartLendingAnalysis",
          "textract:CreateAdapter",
          "textract:DeleteAdapter",
          "textract:GetAdapter",
          "textract:ListAdapters",
          "textract:UpdateAdapter",
          "textract:CreateAdapterVersion",
          "textract:DeleteAdapterVersion",
          "textract:GetAdapterVersion",
          "textract:ListAdapterVersions",
          "textract:TagResource",
          "textract:UntagResource",
          "textract:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "marketplace-textract-policy"
      Component = "iam-policy"
    }
  )
}

# IAM Policy for Amazon SES (Email)
resource "aws_iam_policy" "marketplace_ses" {
  name        = "marketplace-ses-policy"
  description = "Full access to Amazon SES for email operations"
  path        = "/service/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SESFullAccess"
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SendTemplatedEmail",
          "ses:SendBulkTemplatedEmail",
          "ses:GetAccount",
          "ses:GetSendQuota",
          "ses:GetSendStatistics",
          "ses:ListIdentities",
          "ses:GetIdentityVerificationAttributes",
          "ses:GetIdentityNotificationAttributes",
          "ses:GetIdentityDkimAttributes",
          "ses:GetIdentityMailFromDomainAttributes",
          "ses:VerifyEmailIdentity",
          "ses:VerifyDomainIdentity",
          "ses:VerifyDomainDkim",
          "ses:DeleteIdentity",
          "ses:SetIdentityMailFromDomain",
          "ses:SetIdentityNotificationTopic",
          "ses:SetIdentityFeedbackForwardingEnabled",
          "ses:CreateEmailIdentity",
          "ses:DeleteEmailIdentity",
          "ses:GetEmailIdentity",
          "ses:ListEmailIdentities",
          "ses:CreateEmailTemplate",
          "ses:DeleteEmailTemplate",
          "ses:GetEmailTemplate",
          "ses:ListEmailTemplates",
          "ses:UpdateEmailTemplate",
          "ses:TestRenderEmailTemplate",
          "ses:CreateConfigurationSet",
          "ses:DeleteConfigurationSet",
          "ses:GetConfigurationSet",
          "ses:ListConfigurationSets",
          "ses:UpdateConfigurationSetEventDestination",
          "ses:CreateConfigurationSetEventDestination",
          "ses:DeleteConfigurationSetEventDestination",
          "ses:PutAccountDetails",
          "ses:PutAccountSendingAttributes",
          "ses:PutEmailIdentityDkimAttributes",
          "ses:PutEmailIdentityFeedbackAttributes",
          "ses:PutEmailIdentityMailFromAttributes",
          "ses:TagResource",
          "ses:UntagResource",
          "ses:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "marketplace-ses-policy"
      Component = "iam-policy"
    }
  )
}

# IAM Policy for S3 Access (Textract needs S3 for async operations)
resource "aws_iam_policy" "marketplace_s3" {
  name        = "marketplace-s3-policy"
  description = "S3 access for Textract async operations and file storage"
  path        = "/service/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3TextractAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::marketplace-*",
          "arn:aws:s3:::marketplace-*/*"
        ]
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "marketplace-s3-policy"
      Component = "iam-policy"
    }
  )
}

# Attach policies to user
resource "aws_iam_user_policy_attachment" "marketplace_textract" {
  user       = aws_iam_user.marketplace.name
  policy_arn = aws_iam_policy.marketplace_textract.arn
}

resource "aws_iam_user_policy_attachment" "marketplace_ses" {
  user       = aws_iam_user.marketplace.name
  policy_arn = aws_iam_policy.marketplace_ses.arn
}

resource "aws_iam_user_policy_attachment" "marketplace_s3" {
  user       = aws_iam_user.marketplace.name
  policy_arn = aws_iam_policy.marketplace_s3.arn
}
