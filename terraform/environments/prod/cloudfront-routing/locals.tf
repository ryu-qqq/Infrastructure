# ========================================
# Local Variables
# ========================================

locals {
  name_prefix = "${var.environment}-cloudfront-routing"

  # Required tags for governance compliance
  required_tags = {
    Owner       = "fbtkdals2@naver.com"
    CostCenter  = "infrastructure"
    Environment = var.environment
    Lifecycle   = "production"
    DataClass   = "internal"
    Service     = "cloudfront-routing"
  }

  # Public static file paths (for DRY cache behaviors)
  public_static_paths = [
    "/favicon.ico",
    "/robots.txt",
    "/sitemap*.xml",
  ]
}
