# CloudFront Distribution Module

AWS CloudFront CDN distribution을 생성하고 관리하는 Terraform 모듈입니다.

## Features

- ✅ **다양한 Origin 지원**: S3, ALB, Custom origin 설정
- ✅ **캐시 동작 설정**: Default 및 Path-based cache behaviors
- ✅ **SSL/TLS 인증서**: ACM 인증서 또는 CloudFront 기본 인증서
- ✅ **에러 응답 커스터마이징**: Custom error responses
- ✅ **로깅**: S3 버킷으로 액세스 로그 전송
- ✅ **WAF 통합**: AWS WAF Web ACL 연결
- ✅ **지역 제한**: Geo-restriction 설정
- ✅ **Lambda@Edge / CloudFront Functions**: Edge computing 지원
- ✅ **표준 태그 적용**: 거버넌스 태그 자동 적용

## Usage

### Basic Example (S3 Origin)

```hcl
module "cdn" {
  source = "../../modules/cloudfront"

  comment = "my-app-cdn"
  enabled = true

  # S3 Origin
  origins = {
    s3 = {
      domain_name = "my-bucket.s3.ap-northeast-2.amazonaws.com"
      origin_id   = "S3-my-bucket"

      s3_origin_config = {
        origin_access_identity = aws_cloudfront_origin_access_identity.this.cloudfront_access_identity_path
      }
    }
  }

  # Default Cache Behavior
  default_cache_behavior = {
    target_origin_id       = "S3-my-bucket"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values = {
      query_string = false
      headers      = []
      cookies = {
        forward = "none"
      }
    }
  }

  # Common tags
  common_tags = {
    Environment = "prod"
    Service     = "my-app"
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
  }
}
```

### Advanced Example (ALB Origin with Custom Domain)

```hcl
module "cdn" {
  source = "../../modules/cloudfront"

  comment = "my-api-cdn"
  enabled = true
  aliases = ["api.example.com"]

  # ALB Origin
  origins = {
    alb = {
      domain_name = "my-alb-123456.ap-northeast-2.elb.amazonaws.com"
      origin_id   = "ALB-my-api"

      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }

      custom_headers = {
        "X-Custom-Header" = "value"
      }
    }
  }

  # Default Cache Behavior
  default_cache_behavior = {
    target_origin_id       = "ALB-my-api"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    default_ttl            = 300
    max_ttl                = 600
    min_ttl                = 0

    forwarded_values = {
      query_string = true
      headers      = ["Host", "Authorization"]
      cookies = {
        forward = "all"
      }
    }
  }

  # Path-based routing
  ordered_cache_behaviors = [
    {
      path_pattern           = "/api/*"
      target_origin_id       = "ALB-my-api"
      viewer_protocol_policy = "https-only"
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      default_ttl            = 0
      max_ttl                = 0
      min_ttl                = 0

      forwarded_values = {
        query_string = true
        headers      = ["*"]
        cookies = {
          forward = "all"
        }
      }
    }
  ]

  # Custom Error Responses
  custom_error_responses = [
    {
      error_code         = 404
      response_code      = 404
      response_page_path = "/404.html"
    },
    {
      error_code         = 403
      response_code      = 403
      response_page_path = "/403.html"
    }
  ]

  # ACM Certificate
  viewer_certificate = {
    acm_certificate_arn            = aws_acm_certificate.this.arn
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  # Logging
  logging_config = {
    bucket          = "my-logs-bucket.s3.amazonaws.com"
    include_cookies = false
    prefix          = "cloudfront/"
  }

  # WAF
  web_acl_id = aws_wafv2_web_acl.this.arn

  common_tags = {
    Environment = "prod"
    Service     = "my-api"
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `comment` | Comment for the CloudFront distribution | `string` | n/a | yes |
| `origins` | Configuration for one or more origins | `map(object)` | n/a | yes |
| `default_cache_behavior` | Default cache behavior configuration | `object` | n/a | yes |
| `aliases` | List of CNAMEs (alternate domain names) | `list(string)` | `[]` | no |
| `common_tags` | Common tags to apply | `map(string)` | `{}` | no |
| `custom_error_responses` | Custom error response configuration | `list(object)` | `[]` | no |
| `default_root_object` | Default root object | `string` | `"index.html"` | no |
| `enabled` | Whether the distribution is enabled | `bool` | `true` | no |
| `geo_restriction` | Geographic restriction configuration | `object` | `{restriction_type = "none"}` | no |
| `http_version` | Maximum HTTP version (http1.1, http2, http2and3, http3) | `string` | `"http2"` | no |
| `is_ipv6_enabled` | Whether IPv6 is enabled | `bool` | `true` | no |
| `logging_config` | Logging configuration | `object` | `null` | no |
| `ordered_cache_behaviors` | Ordered list of cache behaviors | `list(object)` | `[]` | no |
| `price_class` | Price class (PriceClass_All, PriceClass_200, PriceClass_100) | `string` | `"PriceClass_100"` | no |
| `retain_on_delete` | Disable instead of delete when destroying | `bool` | `false` | no |
| `viewer_certificate` | SSL/TLS certificate configuration | `object` | `{cloudfront_default_certificate = true}` | no |
| `wait_for_deployment` | Wait for deployment before completing | `bool` | `true` | no |
| `web_acl_id` | AWS WAF web ACL ARN | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| `distribution_arn` | ARN of the CloudFront distribution |
| `distribution_domain_name` | Domain name of the CloudFront distribution |
| `distribution_hosted_zone_id` | CloudFront Route 53 zone ID for alias records |
| `distribution_id` | ID of the CloudFront distribution |
| `distribution_status` | Current status of the CloudFront distribution |
| `distribution_etag` | ETag of the CloudFront distribution |

## Examples

자세한 예제는 [examples/](./examples/) 디렉토리를 참고하세요:

- [basic](./examples/basic/) - 기본 S3 origin 설정
- [with-s3-origin](./examples/with-s3-origin/) - S3 origin with OAI

## Notes

### Price Classes

- **PriceClass_All**: 모든 엣지 로케이션 (가장 비쌈, 가장 빠름)
- **PriceClass_200**: 대부분의 엣지 로케이션 (북미, 유럽, 아시아, 중동, 아프리카)
- **PriceClass_100**: 가장 저렴한 엣지 로케이션 (북미, 유럽)

### Cache Invalidation

배포 후 캐시 무효화가 필요한 경우:

```bash
aws cloudfront create-invalidation \
  --distribution-id <distribution-id> \
  --paths "/*"
```

### Origin Access Identity (S3)

S3 origin 사용 시 Origin Access Identity를 생성해야 합니다:

```hcl
resource "aws_cloudfront_origin_access_identity" "this" {
  comment = "OAI for my-bucket"
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.this.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.this.arn}/*"
      }
    ]
  })
}
```

## Related Modules

- [s3-bucket](../s3-bucket/) - S3 버킷 생성 (origin으로 사용)
- [alb](../alb/) - ALB 생성 (origin으로 사용)
- [waf](../waf/) - WAF Web ACL 생성

## References

- [AWS CloudFront Documentation](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/)
- [Terraform aws_cloudfront_distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution)

---

**Last Updated**: 2025-11-10
**Maintained By**: Infrastructure Team
