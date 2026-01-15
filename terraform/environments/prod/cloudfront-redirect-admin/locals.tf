# Local Variables for Admin Server Redirect

locals {
  name_prefix = "${var.environment}-cloudfront-redirect-admin"

  required_tags = {
    Owner       = "fbtkdals2@naver.com"
    CostCenter  = "infrastructure"
    Environment = var.environment
    Lifecycle   = "production"
    DataClass   = "internal"
    Service     = "admin-redirect"
  }
}
