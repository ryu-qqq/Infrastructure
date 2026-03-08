# Local Variables

locals {
  name_prefix = "${var.environment}-cloudfront"

  # Required tags for governance compliance
  required_tags = {
    Owner       = "fbtkdals2@naver.com"
    CostCenter  = "infrastructure"
    Environment = var.environment
    Lifecycle   = "staging"
    DataClass   = "internal"
    Service     = "cdn"
  }

  # S3 Origins (legacy origins excluded for stage)
  origins = {
    # Default + OTEL Config origin: stage-connectly
    stage_connectly = {
      domain_name = "stage-connectly.s3.${var.aws_region}.amazonaws.com"
      origin_id   = "S3-stage-connectly"
    }

    # FileFlow Uploads origin: fileflow-uploads-stage
    # /public/* (public access) + /internal/* (Signed URL)
    fileflow_uploads = {
      domain_name = "fileflow-uploads-stage.s3.${var.aws_region}.amazonaws.com"
      origin_id   = "S3-fileflow-uploads-stage"
    }
  }
}
