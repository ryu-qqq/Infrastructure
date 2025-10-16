# ALB (Application Load Balancer) Terraform Module

AWS Application Load Balancer를 배포하고 관리하기 위한 재사용 가능한 Terraform 모듈입니다. ALB, Target Groups, Listeners, Listener Rules를 포함한 완전한 로드 밸런싱 스택을 제공합니다.

## Features

- ✅ Application Load Balancer 자동 생성
- ✅ 다중 Target Group 지원
- ✅ HTTP/HTTPS Listener 구성
- ✅ SSL/TLS 인증서 관리 (ACM 통합)
- ✅ 경로 기반 라우팅 (Path-based routing)
- ✅ 호스트 기반 라우팅 (Host-based routing)
- ✅ Health Check 커스터마이징
- ✅ Session Stickiness (쿠키 기반)
- ✅ Access Logs (S3 연동)
- ✅ HTTP to HTTPS 자동 리다이렉트
- ✅ 포괄적인 변수 검증
- ✅ 표준화된 태그 자동 적용

## Usage

### Basic Example

```hcl
# 기본 ALB with HTTP to HTTPS redirect
module "alb" {
  source = "../../modules/alb"

  name       = "my-alb"
  vpc_id     = "vpc-xxxxx"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

  security_group_ids = [aws_security_group.alb.id]

  # HTTP Listener with redirect
  http_listeners = {
    default = {
      port     = 80
      protocol = "HTTP"
      default_action = {
        type = "redirect"
        redirect = {
          port        = "443"
          protocol    = "HTTPS"
          status_code = "HTTP_301"
        }
      }
    }
  }

  # Target Group
  target_groups = {
    app = {
      port     = 8080
      protocol = "HTTP"

      health_check = {
        enabled             = true
        path                = "/health"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 3
        interval            = 30
        matcher             = "200"
      }
    }
  }

  common_tags = {
    Environment = "production"
    Service     = "api"
    ManagedBy   = "Terraform"
  }
}
```

### Advanced Example with HTTPS and Path-based Routing

```hcl
module "alb" {
  source = "../../modules/alb"

  name       = "production-alb"
  vpc_id     = var.vpc_id
  subnet_ids = var.public_subnet_ids

  security_group_ids = [aws_security_group.alb.id]
  enable_http2       = true
  idle_timeout       = 120

  # HTTP Listener - Redirect to HTTPS
  http_listeners = {
    default = {
      port     = 80
      protocol = "HTTP"
      default_action = {
        type = "redirect"
        redirect = {
          port        = "443"
          protocol    = "HTTPS"
          status_code = "HTTP_301"
        }
      }
    }
  }

  # HTTPS Listener
  https_listeners = {
    default = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = data.aws_acm_certificate.selected.arn
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

      default_action = {
        type             = "forward"
        target_group_key = "primary"
      }
    }
  }

  # Multiple Target Groups
  target_groups = {
    primary = {
      port     = 8080
      protocol = "HTTP"

      health_check = {
        path     = "/health"
        interval = 30
        timeout  = 5
        matcher  = "200"
      }

      stickiness = {
        enabled         = true
        cookie_duration = 86400 # 24 hours
      }
    }

    api = {
      port     = 9090
      protocol = "HTTP"

      health_check = {
        path     = "/api/health"
        interval = 15
        timeout  = 3
        matcher  = "200,201"
      }
    }
  }

  # Path-based routing
  listener_rules = {
    api_routing = {
      listener_key = "default"
      priority     = 100

      conditions = [
        {
          path_pattern = ["/api/*"]
        }
      ]

      actions = [
        {
          type             = "forward"
          target_group_key = "api"
        }
      ]
    }
  }

  # Access Logs
  access_logs = {
    bucket  = "my-alb-logs-bucket"
    enabled = true
    prefix  = "production-alb"
  }

  common_tags = {
    Environment = "production"
    Service     = "api"
    ManagedBy   = "Terraform"
  }
}
```

### Complete Example

전체 기능을 활용한 실제 운영 시나리오는 [examples/advanced](./examples/advanced/) 디렉터리를 참조하세요.

## Inputs

### Required Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name` | ALB 이름 (최대 32자) | `string` | - | yes |
| `subnet_ids` | ALB가 배포될 서브넷 ID 목록 (최소 2개, 다른 AZ) | `list(string)` | - | yes |
| `vpc_id` | ALB가 생성될 VPC ID | `string` | - | yes |

### Optional Variables - ALB Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `common_tags` | 모든 리소스에 적용할 공통 태그 | `map(string)` | `{}` | no |
| `enable_deletion_protection` | 삭제 방지 활성화 | `bool` | `false` | no |
| `enable_http2` | HTTP/2 활성화 | `bool` | `true` | no |
| `idle_timeout` | 연결 유휴 타임아웃 (초, 1-4000) | `number` | `60` | no |
| `internal` | 내부 ALB 여부 (false = internet-facing) | `bool` | `false` | no |
| `ip_address_type` | IP 주소 타입 (ipv4 또는 dualstack) | `string` | `"ipv4"` | no |
| `security_group_ids` | ALB에 연결할 보안 그룹 ID 목록 | `list(string)` | `[]` | no |

### Optional Variables - Target Groups

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `target_groups` | Target Group 구성 맵 | `map(object)` | `{}` | no |

Target Group 객체 구조:
- `port` - 대상 포트 (required)
- `protocol` - 프로토콜 (HTTP, HTTPS) (default: "HTTP")
- `target_type` - 대상 타입 (ip, instance, lambda) (default: "ip")
- `deregistration_delay` - 등록 해제 대기 시간 (초) (default: 300)
- `health_check` - Health check 설정
  - `enabled` - Health check 활성화 (default: true)
  - `healthy_threshold` - 정상 임계값 (2-10) (default: 3)
  - `interval` - Health check 간격 (초, 5-300) (default: 30)
  - `matcher` - 정상 응답 코드 (default: "200")
  - `path` - Health check 경로 (default: "/health")
  - `protocol` - Health check 프로토콜 (default: "HTTP")
  - `timeout` - 타임아웃 (초, 2-120) (default: 5)
  - `unhealthy_threshold` - 비정상 임계값 (2-10) (default: 2)
- `stickiness` - Session stickiness 설정
  - `enabled` - Stickiness 활성화 (default: false)
  - `type` - Stickiness 타입 (lb_cookie) (default: "lb_cookie")
  - `cookie_duration` - 쿠키 유지 시간 (초) (default: 86400)

### Optional Variables - Listeners

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `http_listeners` | HTTP Listener 구성 맵 | `map(object)` | `{}` | no |
| `https_listeners` | HTTPS Listener 구성 맵 | `map(object)` | `{}` | no |

HTTP Listener 객체 구조:
- `port` - 리스너 포트 (default: 80)
- `protocol` - 프로토콜 (HTTP) (default: "HTTP")
- `default_action` - 기본 액션
  - `type` - 액션 타입 (forward, redirect, fixed-response)
  - `target_group_key` - 대상 Target Group 키 (type이 forward인 경우)
  - `redirect` - 리다이렉트 설정 (type이 redirect인 경우)
  - `fixed_response` - 고정 응답 설정 (type이 fixed-response인 경우)

HTTPS Listener 객체 구조:
- `port` - 리스너 포트 (default: 443)
- `protocol` - 프로토콜 (HTTPS) (default: "HTTPS")
- `certificate_arn` - ACM 인증서 ARN (required)
- `ssl_policy` - SSL 보안 정책 (default: "ELBSecurityPolicy-TLS13-1-2-2021-06")
- `default_action` - 기본 액션

### Optional Variables - Listener Rules

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `listener_rules` | Listener Rule 구성 맵 (경로/호스트 기반 라우팅) | `map(object)` | `{}` | no |

Listener Rule 객체 구조:
- `listener_key` - 연결할 리스너 키 (required)
- `priority` - 규칙 우선순위 (1-50000) (required)
- `conditions` - 조건 목록
  - `path_pattern` - 경로 패턴 목록 (예: ["/api/*"])
  - `host_header` - 호스트 헤더 목록 (예: ["example.com"])
- `actions` - 액션 목록
  - `type` - 액션 타입 (forward, redirect, fixed-response)
  - `target_group_key` - 대상 Target Group 키

### Optional Variables - Access Logs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `access_logs` | Access Logs 구성 | `object` | `null` | no |

Access Logs 객체 구조:
- `bucket` - S3 버킷 이름 (required)
- `enabled` - Access logs 활성화 (default: true)
- `prefix` - S3 키 prefix (optional)

## Outputs

### ALB Outputs

| Name | Description |
|------|-------------|
| `alb_arn` | ALB ARN |
| `alb_arn_suffix` | ALB ARN suffix (CloudWatch 메트릭용) |
| `alb_dns_name` | ALB DNS 이름 |
| `alb_id` | ALB ID |
| `alb_zone_id` | ALB Route53 호스팅 영역 ID (alias 레코드용) |

### Target Group Outputs

| Name | Description |
|------|-------------|
| `target_group_arns` | Target Group ARN 맵 |
| `target_group_arn_suffixes` | Target Group ARN suffix 맵 (CloudWatch 메트릭용) |
| `target_group_ids` | Target Group ID 맵 |
| `target_group_names` | Target Group 이름 맵 |

### Listener Outputs

| Name | Description |
|------|-------------|
| `http_listener_arns` | HTTP Listener ARN 맵 |
| `http_listener_ids` | HTTP Listener ID 맵 |
| `https_listener_arns` | HTTPS Listener ARN 맵 |
| `https_listener_ids` | HTTPS Listener ID 맵 |

### Listener Rule Outputs

| Name | Description |
|------|-------------|
| `listener_rule_arns` | Listener Rule ARN 맵 |
| `listener_rule_ids` | Listener Rule ID 맵 |

## Resource Types

이 모듈은 다음 AWS 리소스를 생성합니다:

- `aws_lb.this` - Application Load Balancer
- `aws_lb_target_group.this` - Target Groups (map)
- `aws_lb_listener.http` - HTTP Listeners (map)
- `aws_lb_listener.https` - HTTPS Listeners (map)
- `aws_lb_listener_rule.this` - Listener Rules (map)

## Validation Rules

모듈은 다음 항목을 자동으로 검증합니다:

- ✅ ALB 이름 규칙 (영숫자, 하이픈만, 최대 32자)
- ✅ 최소 2개 서브넷 (고가용성)
- ✅ VPC ID 형식 (vpc- prefix)
- ✅ 유휴 타임아웃 범위 (1-4000초)
- ✅ IP 주소 타입 (ipv4 또는 dualstack)
- ✅ Health check 타임아웃 < 간격
- ✅ Lambda 타겟은 HTTP 프로토콜만 사용

유효하지 않은 입력은 `terraform plan` 단계에서 명확한 에러 메시지와 함께 실패합니다.

## Tags Applied

모든 리소스는 자동으로 다음 태그를 받습니다:

**공통 태그 (사용자 제공):**
- 사용자가 `common_tags`로 전달한 모든 태그

**모듈별 태그:**
- `Name` - 리소스 이름
- `Description` - 리소스 설명

## Examples Directory

추가 사용 예제는 [examples/](./examples/) 디렉터리를 참조하세요:

- [basic/](./examples/basic/) - 최소 설정 예제 (HTTP redirect)
- [advanced/](./examples/advanced/) - 고급 기능 활용 예제 (HTTPS, 다중 Target Group, 경로 기반 라우팅)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0.0 |

## Related Documentation

- [모듈 디렉터리 구조](../../../docs/MODULES_DIRECTORY_STRUCTURE.md)
- [모듈 표준 가이드](../../../docs/MODULE_STANDARDS_GUIDE.md)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Target Group Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)

## Changelog

변경 이력은 [CHANGELOG.md](./CHANGELOG.md)를 참조하세요.

## Epic & Tasks

- **Epic**: [IN-100 - 재사용 가능한 표준 모듈](https://ryuqqq.atlassian.net/browse/IN-100)
- **Task**: [IN-124 - TASK 4-4: ALB 모듈 개발](https://ryuqqq.atlassian.net/browse/IN-124)

## License

Internal use only - Infrastructure Team

---

## Advanced Configuration

### HTTPS with ACM Certificate

```hcl
data "aws_acm_certificate" "selected" {
  domain   = "example.com"
  statuses = ["ISSUED"]
}

module "alb" {
  source = "../../modules/alb"
  # ...

  https_listeners = {
    default = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = data.aws_acm_certificate.selected.arn
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

      default_action = {
        type             = "forward"
        target_group_key = "app"
      }
    }
  }
}
```

### Multiple Target Groups with Path-based Routing

```hcl
module "alb" {
  source = "../../modules/alb"
  # ...

  target_groups = {
    web = {
      port = 8080
      health_check = { path = "/" }
    }
    api = {
      port = 9090
      health_check = { path = "/api/health" }
    }
    admin = {
      port = 8081
      health_check = { path = "/admin/health" }
    }
  }

  listener_rules = {
    api_routing = {
      listener_key = "default"
      priority     = 100
      conditions = [{ path_pattern = ["/api/*"] }]
      actions = [{ type = "forward", target_group_key = "api" }]
    }
    admin_routing = {
      listener_key = "default"
      priority     = 200
      conditions = [{ path_pattern = ["/admin/*"] }]
      actions = [{ type = "forward", target_group_key = "admin" }]
    }
  }
}
```

### Host-based Routing

```hcl
listener_rules = {
  app_domain = {
    listener_key = "default"
    priority     = 300
    conditions = [
      {
        host_header = ["app.example.com", "www.example.com"]
      }
    ]
    actions = [
      {
        type             = "forward"
        target_group_key = "primary"
      }
    ]
  }
}
```

### Session Stickiness

```hcl
target_groups = {
  app = {
    port = 8080
    stickiness = {
      enabled         = true
      type            = "lb_cookie"
      cookie_duration = 86400  # 24 hours
    }
  }
}
```

## Troubleshooting

### Target가 Unhealthy 상태

**증상**: Target Group에 등록된 타겟이 계속 Unhealthy

**해결**:
1. Health check 경로가 올바른지 확인 (`/health` 엔드포인트 구현 확인)
2. Health check 타임아웃과 간격 조정
3. 보안 그룹 규칙 확인 (ALB → Target 트래픽 허용)
4. Target의 애플리케이션 로그 확인

### HTTPS 리스너 생성 실패

**증상**: ACM 인증서 관련 에러

**해결**:
1. 인증서가 발급 완료 상태인지 확인 (status = ISSUED)
2. 인증서가 올바른 리전에 있는지 확인
3. ALB가 인증서 도메인에 맞는 서브넷에 있는지 확인

### 경로 기반 라우팅이 작동하지 않음

**증상**: 모든 요청이 기본 Target Group으로 전달됨

**해결**:
1. Listener Rule의 우선순위(priority) 확인
2. 경로 패턴이 올바른지 확인 (`/api/*` vs `/api*`)
3. Listener Rule이 올바른 리스너에 연결되었는지 확인

## Security Considerations

- 퍼블릭 서브넷에 ALB 배포 (internet-facing)
- HTTPS 사용 강제 (HTTP → HTTPS 리다이렉트)
- 최신 TLS 보안 정책 사용 (TLS 1.3)
- 보안 그룹으로 인바운드 트래픽 제한
- Access Logs 활성화하여 모니터링 강화
- WAF 통합 고려 (DDoS 방어)

## Performance Considerations

- Health check 간격 최적화 (너무 빈번하면 부하)
- Connection draining 시간 적절히 설정
- HTTP/2 활성화 (기본 활성화)
- Session stickiness 사용 시 트래픽 분산 고려
- 적절한 idle timeout 설정

## Cost Optimization

- 불필요한 Target Group 제거
- Access Logs S3 수명 주기 정책 설정
- Idle connection 타임아웃 최적화
- Target 수 최소화 (적절한 인스턴스 크기 선택)
