# 다중 Target Group을 사용하는 ALB 예제

이 예제는 하나의 Application Load Balancer에서 경로 기반 라우팅을 사용하여 여러 Target Group으로 트래픽을 분산하는 방법을 보여줍니다. 마이크로서비스 아키텍처에서 API Gateway 역할을 하는 ALB 구성에 적합합니다.

## 아키텍처

```
Internet
    |
    v
Application Load Balancer
    |
    +--- /api/*     → API Target Group (Port 8080)
    +--- /admin/*   → Admin Target Group (Port 8081)
    +--- /health    → Fixed Response (200 OK)
    +--- /*         → Web Target Group (Port 3000, default)
```

## 주요 기능

- ✅ 단일 ALB에서 여러 서비스 호스팅
- ✅ 경로 기반 라우팅 (Path-based routing)
- ✅ HTTP → HTTPS 자동 리다이렉트
- ✅ Target Group별 독립적인 헬스체크
- ✅ 고정 응답 (Fixed Response) 지원
- ✅ 우선순위 기반 라우팅 규칙

## 라우팅 규칙

| 우선순위 | 경로 패턴 | 대상 | 설명 |
|---------|----------|------|------|
| 100 | `/api/*` | API Target Group | API 서비스로 라우팅 |
| 200 | `/admin/*` | Admin Target Group | 관리자 서비스로 라우팅 |
| 300 | `/health`, `/healthz` | Fixed Response | 200 OK 고정 응답 |
| default | `/*` | Web Target Group | 나머지 모든 요청 (웹 프론트엔드) |

## 사용 방법

### 1. terraform.tfvars 파일 생성

```hcl
# terraform.tfvars
aws_region   = "ap-northeast-2"
environment  = "prod"
service_name = "microservices"
vpc_id       = "vpc-xxxxxxxxxxxxx"

# HTTPS 사용 시 (권장)
certificate_arn = "arn:aws:acm:ap-northeast-2:123456789012:certificate/xxxxx"
```

### 2. Terraform 배포

```bash
# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply
```

### 3. 서비스 연결

각 Target Group에 ECS 서비스나 EC2 인스턴스를 연결합니다:

```hcl
# API 서비스 (ECS 예시)
module "api_service" {
  source = "../../ecs-service"

  # ...

  load_balancer_config = {
    target_group_arn = terraform.output.api_target_group_arn
    container_name   = "api"
    container_port   = 8080
  }
}

# Web 서비스
module "web_service" {
  source = "../../ecs-service"

  # ...

  load_balancer_config = {
    target_group_arn = terraform.output.web_target_group_arn
    container_name   = "web"
    container_port   = 3000
  }
}

# Admin 서비스
module "admin_service" {
  source = "../../ecs-service"

  # ...

  load_balancer_config = {
    target_group_arn = terraform.output.admin_target_group_arn
    container_name   = "admin"
    container_port   = 8081
  }
}
```

### 4. 동작 확인

```bash
# ALB DNS 확인
terraform output alb_dns_name

# 각 서비스 테스트
curl https://$(terraform output -raw alb_dns_name)/health        # 200 OK
curl https://$(terraform output -raw alb_dns_name)/api/users     # API 서비스
curl https://$(terraform output -raw alb_dns_name)/admin/        # Admin 서비스
curl https://$(terraform output -raw alb_dns_name)/              # Web 서비스
```

## 출력 값

| 출력 이름 | 설명 |
|----------|------|
| `alb_dns_name` | ALB의 DNS 이름 |
| `api_target_group_arn` | API Target Group ARN |
| `web_target_group_arn` | Web Target Group ARN |
| `admin_target_group_arn` | Admin Target Group ARN |
| `service_urls` | 서비스별 접속 URL |

## Target Group 상세 설정

### API Target Group
- **포트**: 8080
- **헬스체크 경로**: `/api/health`
- **용도**: RESTful API 서비스

### Web Target Group
- **포트**: 3000
- **헬스체크 경로**: `/health`
- **용도**: 프론트엔드 웹 애플리케이션

### Admin Target Group
- **포트**: 8081
- **헬스체크 경로**: `/admin/health`
- **용도**: 관리자 대시보드

## 비용 예상

### 월 예상 비용 (서울 리전 기준)

- **Application Load Balancer**
  - 약 $20/월

- **Data Transfer** (예상 100GB/월)
  - 약 $10/월

**총 예상 비용: 약 $30/월**

> Target Group은 무료이며, 실제 비용은 트래픽 양에 따라 달라집니다.

## 고급 라우팅 패턴

### 호스트 기반 라우팅 추가

```hcl
resource "aws_lb_listener_rule" "api_host" {
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    host_header {
      values = ["api.example.com"]
    }
  }
}
```

### HTTP 헤더 기반 라우팅

```hcl
resource "aws_lb_listener_rule" "mobile_app" {
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 150

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mobile_api.arn
  }

  condition {
    http_header {
      http_header_name = "User-Agent"
      values           = ["*Mobile*"]
    }
  }
}
```

### 가중치 기반 라우팅 (Blue/Green, Canary)

```hcl
resource "aws_lb_listener_rule" "weighted" {
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100

  action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = 90  # 90% 트래픽
      }

      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = 10  # 10% 트래픽
      }
    }
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
```

## 모니터링

### CloudWatch 메트릭

```bash
# Target별 건강 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw api_target_group_arn)

# ALB 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/microservices-prod/xxx \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T01:00:00Z \
  --period 300 \
  --statistics Sum
```

### 액세스 로그 활성화

```hcl
resource "aws_lb" "main" {
  # ...

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb"
    enabled = true
  }
}
```

## 보안 고려사항

1. **경로 기반 접근 제어**
   - `/admin/*` 경로에는 IP 화이트리스트 추가 고려
   - WAF 규칙으로 특정 경로 보호

2. **SSL/TLS 설정**
   - 최신 TLS 1.3 정책 사용
   - ACM 인증서 자동 갱신

3. **보안 그룹**
   - 인터넷에서 80, 443 포트만 허용
   - Target Group별로 ALB에서만 접근 허용

## 트러블슈팅

### 특정 경로 라우팅 실패

1. **Listener Rule 우선순위 확인**
   ```bash
   aws elbv2 describe-rules --listener-arn <listener-arn>
   ```

2. **경로 패턴 테스트**
   - 더 구체적인 경로가 높은 우선순위를 가져야 함
   - 예: `/api/v1/users`는 `/api/*`보다 높은 우선순위

### Target 건강하지 않음

1. **헬스체크 설정 확인**
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn <target-group-arn>
   ```

2. **보안 그룹 확인**
   - Target의 보안 그룹이 ALB 보안 그룹으로부터의 트래픽 허용하는지 확인

## 관련 문서

- [ALB 모듈 README](../../README.md)
- [AWS ALB 라우팅 규칙](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-update-rules.html)
- [경로 기반 라우팅 모범 사례](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/tutorial-load-balancer-routing.html)

## 라이선스

Internal use only - Infrastructure Team
