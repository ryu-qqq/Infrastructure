# CloudFront Distribution 모듈

AWS CloudFront CDN 배포를 생성 및 관리하는 Terraform 모듈입니다. 다중 오리진, 캐시 동작, SSL/TLS 설정, Lambda@Edge 및 CloudFront Functions 통합을 지원합니다.

## 주요 기능

- **다중 오리진 지원**: S3 및 커스텀 오리진 구성
- **유연한 캐시 동작**: 기본 및 정렬된 캐시 동작 설정
- **SSL/TLS 통합**: ACM 인증서 및 커스텀 도메인 지원
- **엣지 컴퓨팅**: Lambda@Edge 및 CloudFront Functions 연결
- **보안 기능**: WAF 통합, 지역 제한, 커스텀 헤더
- **로깅 및 모니터링**: 액세스 로그, 커스텀 에러 응답
- **표준 태깅**: 공통 태그 모듈 통합으로 일관된 리소스 태깅

## 사용 예시

### 기본 S3 오리진 배포

```hcl
module "website_cdn" {
  source = "../../modules/cloudfront"

  comment      = "Static Website CDN"
  environment  = "prod"
  service_name = "website"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  aliases = ["www.example.com", "example.com"]

  origins = {
    s3 = {
      domain_name = aws_s3_bucket.website.bucket_regional_domain_name
      origin_id   = "s3-website"

      s3_origin_config = {
        origin_access_identity = aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3-website"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    default_ttl            = 3600
    max_ttl                = 86400
    min_ttl                = 0

    forwarded_values = {
      query_string = false
      headers      = []
      cookies = {
        forward = "none"
      }
    }
  }

  viewer_certificate = {
    acm_certificate_arn            = aws_acm_certificate.website.arn
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  custom_error_responses = [
    {
      error_code         = 404
      response_code      = 200
      response_page_path = "/index.html"
    }
  ]
}
```

### 커스텀 오리진 (API Gateway/ALB) 배포

```hcl
module "api_cdn" {
  source = "../../modules/cloudfront"

  comment      = "API Gateway CDN"
  environment  = "prod"
  service_name = "api"
  team         = "backend-team"
  owner        = "backend@example.com"
  cost_center  = "engineering"

  origins = {
    api = {
      domain_name = "api.example.com"
      origin_id   = "custom-api"

      custom_origin_config = {
        http_port                = 80
        https_port               = 443
        origin_protocol_policy   = "https-only"
        origin_ssl_protocols     = ["TLSv1.2"]
        origin_keepalive_timeout = 5
        origin_read_timeout      = 30
      }

      custom_headers = {
        "X-Custom-Header" = "value"
        "X-API-Key"       = "secret-key"
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "custom-api"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values = {
      query_string = true
      headers      = ["Authorization", "Accept", "Content-Type"]
      cookies = {
        forward = "all"
      }
    }
  }

  web_acl_id = aws_wafv2_web_acl.api.arn
}
```

### Lambda@Edge 및 CloudFront Functions 통합

```hcl
module "dynamic_cdn" {
  source = "../../modules/cloudfront"

  comment      = "Dynamic Content CDN"
  environment  = "prod"
  service_name = "dynamic-content"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  origins = {
    primary = {
      domain_name = "origin.example.com"
      origin_id   = "primary-origin"

      custom_origin_config = {
        origin_protocol_policy = "https-only"
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "primary-origin"
    viewer_protocol_policy = "redirect-to-https"

    # CloudFront Functions
    function_associations = [
      {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.url_rewrite.arn
      }
    ]

    # Lambda@Edge
    lambda_function_associations = [
      {
        event_type   = "origin-response"
        lambda_arn   = "${aws_lambda_function.security_headers.arn}:${aws_lambda_function.security_headers.version}"
        include_body = false
      }
    ]
  }
}
```

### 다중 오리진 및 경로 기반 라우팅

```hcl
module "multi_origin_cdn" {
  source = "../../modules/cloudfront"

  comment      = "Multi-Origin CDN"
  environment  = "prod"
  service_name = "multi-origin"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  origins = {
    static = {
      domain_name = aws_s3_bucket.static.bucket_regional_domain_name
      origin_id   = "s3-static"

      s3_origin_config = {
        origin_access_identity = aws_cloudfront_origin_access_identity.static.cloudfront_access_identity_path
      }
    }

    api = {
      domain_name = "api.example.com"
      origin_id   = "api-origin"

      custom_origin_config = {
        origin_protocol_policy = "https-only"
      }
    }

    images = {
      domain_name = aws_s3_bucket.images.bucket_regional_domain_name
      origin_id   = "s3-images"
      origin_path = "/resized"

      s3_origin_config = {
        origin_access_identity = aws_cloudfront_origin_access_identity.images.cloudfront_access_identity_path
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3-static"
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behaviors = [
    {
      path_pattern           = "/api/*"
      target_origin_id       = "api-origin"
      viewer_protocol_policy = "https-only"
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD"]
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
    },
    {
      path_pattern           = "/images/*"
      target_origin_id       = "s3-images"
      viewer_protocol_policy = "redirect-to-https"
      compress               = true
      default_ttl            = 86400
      max_ttl                = 31536000
    }
  ]
}
```

### 로깅 및 지역 제한 설정

```hcl
module "restricted_cdn" {
  source = "../../modules/cloudfront"

  comment      = "Region Restricted CDN"
  environment  = "prod"
  service_name = "restricted-content"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  origins = {
    primary = {
      domain_name = "origin.example.com"
      origin_id   = "primary"

      custom_origin_config = {
        origin_protocol_policy = "https-only"
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "primary"
    viewer_protocol_policy = "redirect-to-https"
  }

  # 액세스 로그 설정
  logging_config = {
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    include_cookies = false
    prefix          = "cloudfront/"
  }

  # 지역 제한 (한국, 일본만 허용)
  geo_restriction = {
    restriction_type = "whitelist"
    locations        = ["KR", "JP"]
  }

  # 프라이스 클래스 (아시아 태평양 전용)
  price_class = "PriceClass_200"
}
```

## 입력 변수

### 필수 변수

| 변수 | 타입 | 설명 | 검증 규칙 |
|------|------|------|-----------|
| `comment` | `string` | CloudFront 배포 설명 | 1-128자 |
| `origins` | `map(object)` | 오리진 구성 맵 | 최소 1개 이상 |
| `default_cache_behavior` | `object` | 기본 캐시 동작 설정 | - |

### 필수 변수 (태깅)

| 변수 | 타입 | 설명 | 검증 규칙 |
|------|------|------|-----------|
| `environment` | `string` | 환경 이름 | `dev`, `staging`, `prod` 중 하나 |
| `service_name` | `string` | 서비스 이름 | kebab-case |
| `team` | `string` | 담당 팀 | kebab-case |
| `owner` | `string` | 리소스 소유자 | 이메일 또는 kebab-case |
| `cost_center` | `string` | 비용 센터 | kebab-case |

### 선택적 변수 (배포 구성)

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `aliases` | `list(string)` | `[]` | CNAME 목록 (대체 도메인 이름) |
| `default_root_object` | `string` | `"index.html"` | 루트 URL 요청 시 반환할 객체 |
| `enabled` | `bool` | `true` | 배포 활성화 여부 |
| `http_version` | `string` | `"http2"` | 최대 HTTP 버전 (`http1.1`, `http2`, `http2and3`, `http3`) |
| `is_ipv6_enabled` | `bool` | `true` | IPv6 활성화 여부 |
| `price_class` | `string` | `"PriceClass_100"` | 가격 클래스 (`PriceClass_All`, `PriceClass_200`, `PriceClass_100`) |
| `retain_on_delete` | `bool` | `false` | 삭제 시 비활성화 (삭제 방지) |
| `wait_for_deployment` | `bool` | `true` | 배포 완료 대기 여부 |
| `web_acl_id` | `string` | `null` | AWS WAF Web ACL ARN |

### 선택적 변수 (캐시 동작)

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `ordered_cache_behaviors` | `list(object)` | `[]` | 정렬된 캐시 동작 목록 |
| `custom_error_responses` | `list(object)` | `[]` | 커스텀 에러 응답 구성 |

### 선택적 변수 (로깅 및 제한)

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `logging_config` | `object` | `null` | 로깅 구성 (S3 버킷, 프리픽스 등) |
| `geo_restriction` | `object` | `{restriction_type = "none"}` | 지역 제한 구성 |
| `viewer_certificate` | `object` | `{cloudfront_default_certificate = true}` | SSL/TLS 인증서 구성 |

### 선택적 변수 (태깅)

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `project` | `string` | `"infrastructure"` | 프로젝트 이름 |
| `data_class` | `string` | `"public"` | 데이터 분류 (`confidential`, `internal`, `public`) |
| `additional_tags` | `map(string)` | `{}` | 추가 태그 |

## 출력

| 출력 | 설명 |
|------|------|
| `distribution_arn` | CloudFront 배포 ARN |
| `distribution_domain_name` | CloudFront 배포 도메인 이름 |
| `distribution_hosted_zone_id` | Route 53 별칭 레코드용 호스팅 영역 ID |
| `distribution_id` | CloudFront 배포 ID |
| `distribution_status` | CloudFront 배포 현재 상태 |
| `distribution_etag` | CloudFront 배포 ETag (업데이트용) |
| `distribution_in_progress_validation_batches` | 진행 중인 무효화 배치 수 |
| `distribution_last_modified_time` | CloudFront 배포 마지막 수정 시간 |
| `distribution_caller_reference` | CloudFront 내부 참조값 (업데이트용) |

## 오리진 구성 상세

### S3 오리진

```hcl
origins = {
  s3 = {
    domain_name = aws_s3_bucket.example.bucket_regional_domain_name
    origin_id   = "s3-origin"
    origin_path = "/static"  # 선택적

    s3_origin_config = {
      origin_access_identity = aws_cloudfront_origin_access_identity.example.cloudfront_access_identity_path
    }

    custom_headers = {
      "X-Custom-Header" = "value"
    }
  }
}
```

### 커스텀 오리진 (ALB, API Gateway, EC2 등)

```hcl
origins = {
  custom = {
    domain_name = "origin.example.com"
    origin_id   = "custom-origin"

    custom_origin_config = {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"  # "http-only", "match-viewer", "https-only"
      origin_ssl_protocols     = ["TLSv1.2", "TLSv1.3"]
      origin_keepalive_timeout = 5   # 초
      origin_read_timeout      = 30  # 초
    }

    custom_headers = {
      "X-Origin-Verify" = "secret-token"
    }
  }
}
```

## 캐시 동작 상세

### 기본 캐시 동작

```hcl
default_cache_behavior = {
  target_origin_id       = "primary-origin"
  viewer_protocol_policy = "redirect-to-https"  # "allow-all", "https-only", "redirect-to-https"
  allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
  cached_methods         = ["GET", "HEAD", "OPTIONS"]
  compress               = true
  default_ttl            = 3600   # 1시간
  max_ttl                = 86400  # 24시간
  min_ttl                = 0

  forwarded_values = {
    query_string = true
    headers      = ["Authorization", "Accept"]
    cookies = {
      forward           = "whitelist"  # "none", "whitelist", "all"
      whitelisted_names = ["session-id", "user-token"]
    }
  }

  # CloudFront Functions
  function_associations = [
    {
      event_type   = "viewer-request"  # "viewer-request", "viewer-response"
      function_arn = aws_cloudfront_function.example.arn
    }
  ]

  # Lambda@Edge
  lambda_function_associations = [
    {
      event_type   = "origin-request"  # "viewer-request", "origin-request", "origin-response", "viewer-response"
      lambda_arn   = "${aws_lambda_function.example.arn}:1"
      include_body = false
    }
  ]
}
```

### 정렬된 캐시 동작 (경로 기반 라우팅)

```hcl
ordered_cache_behaviors = [
  {
    path_pattern           = "/api/*"
    target_origin_id       = "api-origin"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = false
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
  },
  {
    path_pattern           = "/static/*"
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    default_ttl            = 86400
    max_ttl                = 31536000
  }
]
```

## 보안 구성

### SSL/TLS 인증서

```hcl
# ACM 인증서 사용 (커스텀 도메인)
viewer_certificate = {
  acm_certificate_arn            = aws_acm_certificate.example.arn
  cloudfront_default_certificate = false
  minimum_protocol_version       = "TLSv1.2_2021"
  ssl_support_method             = "sni-only"  # "sni-only" 또는 "vip"
}

# CloudFront 기본 인증서 사용
viewer_certificate = {
  cloudfront_default_certificate = true
  minimum_protocol_version       = "TLSv1"
}
```

### WAF 통합

```hcl
web_acl_id = aws_wafv2_web_acl.example.arn
```

### 지역 제한

```hcl
# 특정 국가만 허용
geo_restriction = {
  restriction_type = "whitelist"
  locations        = ["KR", "JP", "US"]
}

# 특정 국가 차단
geo_restriction = {
  restriction_type = "blacklist"
  locations        = ["CN", "RU"]
}

# 제한 없음
geo_restriction = {
  restriction_type = "none"
}
```

## 커스텀 에러 응답

```hcl
custom_error_responses = [
  {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  },
  {
    error_code            = 403
    response_code         = 403
    response_page_path    = "/403.html"
    error_caching_min_ttl = 60
  },
  {
    error_code         = 500
    error_caching_min_ttl = 0  # 서버 에러는 캐시하지 않음
  }
]
```

## 로깅 구성

```hcl
logging_config = {
  bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
  include_cookies = false
  prefix          = "cloudfront/${var.service_name}/"
}
```

**참고**: S3 버킷은 CloudFront 로그 전송 권한이 설정되어 있어야 합니다.

## Price Class 선택 가이드

| Price Class | 엣지 로케이션 | 사용 사례 |
|-------------|--------------|----------|
| `PriceClass_100` | 북미, 유럽 | 비용 최적화, 서부 사용자 대상 |
| `PriceClass_200` | 북미, 유럽, 아시아, 중동, 아프리카 | 글로벌 서비스 (남미 제외) |
| `PriceClass_All` | 모든 엣지 로케이션 | 전세계 최저 지연시간 요구 |

## 거버넌스 규칙

이 모듈은 프로젝트 거버넌스 표준을 준수합니다:

### 1. 필수 태그
`common-tags` 모듈을 통해 자동으로 적용됩니다:
- `Environment`: 환경 (dev/staging/prod)
- `Service`: 서비스 이름
- `Team`: 담당 팀
- `Owner`: 리소스 소유자
- `CostCenter`: 비용 센터
- `Project`: 프로젝트 이름
- `DataClass`: 데이터 분류
- `Lifecycle`: 리소스 수명주기
- `ManagedBy`: Terraform

추가 태그:
- `Name`: 배포 설명 (comment 변수 사용)
- `Description`: CloudFront Distribution 상세 설명
- `Component`: `cdn`

### 2. 명명 규칙
- **변수/로컬**: `snake_case` (예: `service_name`, `default_cache_behavior`)
- **리소스 이름**: `kebab-case` (예: `api-cdn`, `static-website`)

### 3. 보안 요구사항
- **SSL/TLS**: 최소 `TLSv1.2_2021` 권장
- **HTTPS**: `viewer_protocol_policy`를 `redirect-to-https` 또는 `https-only`로 설정 권장
- **WAF**: 프로덕션 환경에서 WAF 연결 권장
- **로깅**: 규정 준수를 위한 액세스 로그 활성화 권장

## 운영 고려사항

### 배포 시간
- 초기 배포: 15-30분
- 업데이트: 5-15분
- `wait_for_deployment = false`로 설정하여 Terraform 실행 시간 단축 가능

### 캐시 무효화
```bash
# 전체 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw distribution_id) \
  --paths "/*"

# 특정 경로 무효화
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw distribution_id) \
  --paths "/images/*" "/css/*"
```

### 비용 최적화
- 적절한 `price_class` 선택 (대상 사용자 지역 고려)
- TTL 값을 최대한 높게 설정하여 오리진 요청 감소
- 압축(`compress = true`) 활성화로 데이터 전송량 감소
- 불필요한 헤더/쿠키 전달 최소화

### 모니터링
```hcl
# CloudWatch 메트릭
# - Requests: 총 요청 수
# - BytesDownloaded: 다운로드된 바이트
# - BytesUploaded: 업로드된 바이트
# - 4xxErrorRate: 4xx 에러율
# - 5xxErrorRate: 5xx 에러율
# - TotalErrorRate: 전체 에러율
```

## 제한사항

- 배포당 최대 25개 오리진
- 배포당 최대 25개 캐시 동작
- 배포당 최대 100개 CNAME 별칭
- Lambda@Edge 함수는 us-east-1 리전에 배포되어야 함
- 배포 수정 시 전파 시간(5-15분) 소요

## 버전 요구사항

- Terraform >= 1.5.0
- AWS Provider >= 5.0

## 관련 문서

- [AWS CloudFront 공식 문서](https://docs.aws.amazon.com/cloudfront/)
- [Terraform AWS Provider - CloudFront Distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution)
- [Lambda@Edge 개발 가이드](https://docs.aws.amazon.com/lambda/latest/dg/lambda-edge.html)
- [CloudFront Functions 가이드](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html)

## 라이선스

이 모듈은 프로젝트 라이선스를 따릅니다.
