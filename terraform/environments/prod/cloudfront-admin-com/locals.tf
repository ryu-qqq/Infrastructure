# Local Variables

locals {
  name_prefix = "${var.environment}-cloudfront-admin-com"

  # Required tags for governance compliance
  required_tags = {
    Owner       = "fbtkdals2@naver.com"
    CostCenter  = "infrastructure"
    Environment = var.environment
    Lifecycle   = "production"
    DataClass   = "internal"
    Service     = "admin"
  }

  # Origins (same pattern as www.set-of.com)
  origins = {
    # API Gateway ALB - /api/v1/* 경로용
    gateway_alb = {
      domain_name = "gateway-alb-prod-1837698569.ap-northeast-2.elb.amazonaws.com"
      origin_id   = "gateway-alb"
    }
    # Admin Frontend ALB - 나머지 경로용 (프론트엔드)
    admin_frontend_alb = {
      domain_name = "setof-admin-web-lb-2114048406.ap-northeast-2.elb.amazonaws.com"
      origin_id   = "frontend-alb"
    }
  }

  # AWS Managed Cache Policies
  cache_policies = {
    # CachingDisabled - 동적 콘텐츠용
    caching_disabled = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # CachingOptimized - 정적 파일용
    caching_optimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    # Custom policy for API (same as www.set-of.com)
    api_cache = "731b35f0-d9fa-4e25-8948-0c088d9420fa"
  }

  # AWS Managed Origin Request Policies
  origin_request_policies = {
    # AllViewer - 모든 헤더, 쿼리스트링, 쿠키 전달
    all_viewer = "216adef6-5c7f-47e4-b989-5492eafa07d3"
    # Custom policy for API (same as www.set-of.com)
    api_origin = "53ed205f-c55c-43d2-b6c4-9eca49b6578b"
  }

  # AWS Managed Response Headers Policies
  response_headers_policies = {
    # Custom policy for API (same as www.set-of.com)
    api_response = "fd37cd93-5c19-475d-a9be-1edbe3ea0e8d"
  }
}
