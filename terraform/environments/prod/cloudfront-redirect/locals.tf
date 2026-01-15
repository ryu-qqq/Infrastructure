# Local Variables

locals {
  name_prefix = "${var.environment}-cloudfront-redirect"

  # Required tags for governance compliance
  required_tags = {
    Owner       = "fbtkdals2@naver.com"
    CostCenter  = "infrastructure"
    Environment = var.environment
    Lifecycle   = "production"
    DataClass   = "internal"
    Service     = "redirect"
  }

  # Route53 Hosted Zone ID for set-of.net
  route53_zone_id = "Z02584341WZ7FPIKF06FI"

  # ACM Certificate ARN for *.set-of.net (us-east-1)
  acm_certificate_arn = "arn:aws:acm:us-east-1:646886795421:certificate/783f28e4-b346-4502-807c-b62fe1293178"
}
