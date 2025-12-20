# Local Variables

locals {
  name_prefix = "${var.environment}-cloudfront"

  # Required tags for governance compliance
  required_tags = {
    Owner       = "fbtkdals2@naver.com"
    CostCenter  = "infrastructure"
    Environment = var.environment
    Lifecycle   = "production"
    DataClass   = "internal"
    Service     = "cdn"
  }

  # S3 Origins
  origins = {
    # 기존 오리진: connectly-prod (레거시, 향후 제거 예정)
    connectly_prod = {
      domain_name = "connectly-prod.s3.${var.aws_region}.amazonaws.com"
      origin_id   = "S3-connectly-prod"
    }

    # OTEL Config 오리진: prod-connectly
    prod_connectly = {
      domain_name = "prod-connectly.s3.${var.aws_region}.amazonaws.com"
      origin_id   = "S3-prod-connectly"
    }

    # FileFlow Uploads 오리진
    fileflow_uploads = {
      domain_name = "fileflow-uploads-prod.s3.${var.aws_region}.amazonaws.com"
      origin_id   = "S3-fileflow-uploads-prod"
    }
  }
}
