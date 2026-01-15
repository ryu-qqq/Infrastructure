# Local Variables for CloudFront www Redirect

locals {
  name_prefix = "${var.environment}-www-redirect"

  # Required tags for governance compliance
  required_tags = {
    Owner       = "fbtkdals2@naver.com"
    CostCenter  = "infrastructure"
    Environment = var.environment
    Lifecycle   = "production"
    DataClass   = "internal"
    Service     = "cloudfront-redirect"
  }
}
