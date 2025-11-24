# ALB (Application Load Balancer) 모듈

AWS Application Load Balancer를 생성하고 관리하는 Terraform 모듈입니다. Target Group, HTTP/HTTPS Listener, Listener Rule을 포함한 완전한 ALB 구성을 지원합니다.

## 주요 기능

- **ALB 생성**: Internet-facing 또는 Internal ALB 지원
- **Target Group 관리**: 다중 Target Group 생성 및 헬스체크 구성
- **HTTP/HTTPS Listener**: 포트 및 프로토콜별 리스너 구성
- **경로 기반 라우팅**: Path Pattern 및 Host Header 기반 Listener Rule
- **액세스 로그**: S3 버킷으로 액세스 로그 전송 (선택)
- **Session Stickiness**: Cookie 기반 세션 고정 지원
- **보안**: 최신 TLS 정책 (TLS 1.3) 기본 적용
- **태그 관리**: common-tags 모듈을 통한 표준화된 태그 관리
- **검증**: 입력값 검증 및 lifecycle precondition을 통한 구성 검증

## 사용 방법

### 기본 사용 예제

```hcl
module "alb" {
  source = "../../modules/alb"

  # 기본 설정
  name       = "api-server-alb"
  vpc_id     = "vpc-xxxxx"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

  security_group_ids = [aws_security_group.alb.id]
  internal           = false

  # Target Group 정의
  target_groups = {
    api = {
      port        = 8080
      protocol    = "HTTP"
      target_type = "ip"

      health_check = {
        path                = "/health"
        healthy_threshold   = 3
        unhealthy_threshold = 2
        timeout             = 5
        interval            = 30
        matcher             = "200"
      }
    }
  }

  # HTTP Listener (HTTPS로 리다이렉트)
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
      certificate_arn = "arn:aws:acm:ap-northeast-2:xxxxx:certificate/xxxxx"
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

      default_action = {
        type             = "forward"
        target_group_key = "api"
      }
    }
  }

  # 태그 설정
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

### 경로 기반 라우팅 예제

```hcl
module "alb" {
  source = "../../modules/alb"

  name       = "web-alb"
  vpc_id     = "vpc-xxxxx"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

  security_group_ids = [aws_security_group.alb.id]

  # 다중 Target Group
  target_groups = {
    web = {
      port        = 3000
      protocol    = "HTTP"
      target_type = "ip"

      health_check = {
        path = "/health"
      }
    }
    api = {
      port        = 8080
      protocol    = "HTTP"
      target_type = "ip"

      health_check = {
        path = "/api/health"
      }
    }
  }

  # HTTPS Listener
  https_listeners = {
    default = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = "arn:aws:acm:ap-northeast-2:xxxxx:certificate/xxxxx"

      default_action = {
        type             = "forward"
        target_group_key = "web"  # 기본: Web으로 라우팅
      }
    }
  }

  # Listener Rules (경로 기반 라우팅)
  listener_rules = {
    api_route = {
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

  # 태그 설정
  environment  = "prod"
  service_name = "web-app"
  team         = "frontend-team"
  owner        = "frontend@example.com"
  cost_center  = "engineering"
}
```

### 세션 고정 및 액세스 로그 예제

```hcl
module "alb" {
  source = "../../modules/alb"

  name       = "session-alb"
  vpc_id     = "vpc-xxxxx"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

  security_group_ids = [aws_security_group.alb.id]

  # 액세스 로그 활성화
  access_logs = {
    bucket  = "my-alb-logs-bucket"
    enabled = true
    prefix  = "alb-logs"
  }

  # Target Group with Stickiness
  target_groups = {
    app = {
      port                 = 8080
      protocol             = "HTTP"
      target_type          = "ip"
      deregistration_delay = 30

      health_check = {
        path = "/health"
      }

      # Session Stickiness 활성화
      stickiness = {
        enabled         = true
        type            = "lb_cookie"
        cookie_duration = 86400  # 1일
      }
    }
  }

  https_listeners = {
    default = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = "arn:aws:acm:ap-northeast-2:xxxxx:certificate/xxxxx"

      default_action = {
        type             = "forward"
        target_group_key = "app"
      }
    }
  }

  # 태그 설정
  environment  = "prod"
  service_name = "session-app"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

## Variables

### 필수 Variables

| 변수명 | 타입 | 설명 |
|--------|------|------|
| `name` | `string` | ALB 이름 (영숫자와 하이픈만, 최대 32자) |
| `subnet_ids` | `list(string)` | ALB가 배치될 서브넷 ID 목록 (최소 2개, 다른 가용영역) |
| `vpc_id` | `string` | ALB가 생성될 VPC ID |
| `environment` | `string` | 환경 이름 (`dev`, `staging`, `prod`) |
| `service_name` | `string` | 서비스 이름 (kebab-case) |
| `team` | `string` | 담당 팀 이름 (kebab-case) |
| `owner` | `string` | 리소스 소유자 (이메일 또는 kebab-case 식별자) |
| `cost_center` | `string` | 비용 센터 (kebab-case) |

### 선택 Variables (ALB 설정)

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `internal` | `bool` | `false` | Internal ALB 여부 (false: Internet-facing) |
| `enable_deletion_protection` | `bool` | `false` | 삭제 방지 활성화 |
| `enable_http2` | `bool` | `true` | HTTP/2 활성화 |
| `idle_timeout` | `number` | `60` | 유휴 연결 타임아웃 (초, 1-4000) |
| `ip_address_type` | `string` | `"ipv4"` | IP 주소 타입 (`ipv4`, `dualstack`) |
| `security_group_ids` | `list(string)` | `[]` | ALB에 연결할 보안 그룹 ID 목록 |
| `access_logs` | `object` | `null` | 액세스 로그 설정 (bucket, enabled, prefix) |

### 선택 Variables (Target Group)

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `target_groups` | `map(object)` | `{}` | Target Group 구성 맵 |
| ↳ `port` | `number` | - | Target 포트 |
| ↳ `protocol` | `string` | `"HTTP"` | 프로토콜 (HTTP, HTTPS) |
| ↳ `target_type` | `string` | `"ip"` | Target 타입 (ip, instance, lambda) |
| ↳ `deregistration_delay` | `number` | `300` | 등록 해제 지연 시간 (초) |
| ↳ `health_check` | `object` | `{}` | 헬스체크 설정 |
| ↳↳ `enabled` | `bool` | `true` | 헬스체크 활성화 |
| ↳↳ `healthy_threshold` | `number` | `3` | 정상 판정 횟수 |
| ↳↳ `unhealthy_threshold` | `number` | `2` | 비정상 판정 횟수 |
| ↳↳ `interval` | `number` | `30` | 헬스체크 간격 (초) |
| ↳↳ `timeout` | `number` | `5` | 헬스체크 타임아웃 (초) |
| ↳↳ `path` | `string` | `"/health"` | 헬스체크 경로 |
| ↳↳ `matcher` | `string` | `"200"` | 정상 응답 코드 |
| ↳↳ `protocol` | `string` | `"HTTP"` | 헬스체크 프로토콜 |
| ↳ `stickiness` | `object` | `{}` | Session Stickiness 설정 |
| ↳↳ `enabled` | `bool` | `false` | Stickiness 활성화 |
| ↳↳ `type` | `string` | `"lb_cookie"` | Stickiness 타입 |
| ↳↳ `cookie_duration` | `number` | `86400` | 쿠키 유지 시간 (초) |

### 선택 Variables (Listener)

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `http_listeners` | `map(object)` | `{}` | HTTP Listener 구성 맵 |
| ↳ `port` | `number` | `80` | 리스너 포트 |
| ↳ `protocol` | `string` | `"HTTP"` | 프로토콜 |
| ↳ `default_action` | `object` | - | 기본 액션 (forward, redirect, fixed-response) |
| `https_listeners` | `map(object)` | `{}` | HTTPS Listener 구성 맵 |
| ↳ `port` | `number` | `443` | 리스너 포트 |
| ↳ `protocol` | `string` | `"HTTPS"` | 프로토콜 |
| ↳ `certificate_arn` | `string` | - | ACM 인증서 ARN (필수) |
| ↳ `ssl_policy` | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | SSL 정책 |
| ↳ `default_action` | `object` | - | 기본 액션 (forward, fixed-response) |

### 선택 Variables (Listener Rule)

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `listener_rules` | `map(object)` | `{}` | Listener Rule 구성 맵 |
| ↳ `listener_key` | `string` | - | Listener 키 (http_listeners 또는 https_listeners의 키) |
| ↳ `priority` | `number` | - | 우선순위 (1-50000) |
| ↳ `conditions` | `list(object)` | - | 조건 목록 (path_pattern, host_header) |
| ↳ `actions` | `list(object)` | - | 액션 목록 (forward, redirect, fixed-response) |

### 선택 Variables (태그)

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `project` | `string` | `"infrastructure"` | 프로젝트 이름 (kebab-case) |
| `data_class` | `string` | `"internal"` | 데이터 분류 (`confidential`, `internal`, `public`) |
| `additional_tags` | `map(string)` | `{}` | 추가 태그 맵 |

## Outputs

### ALB Outputs

| 출력명 | 설명 |
|--------|------|
| `alb_arn` | ALB ARN |
| `alb_arn_suffix` | ALB ARN Suffix (CloudWatch 메트릭용) |
| `alb_dns_name` | ALB DNS 이름 |
| `alb_id` | ALB ID |
| `alb_zone_id` | ALB Hosted Zone ID (Route53 Alias 레코드용) |

### Target Group Outputs

| 출력명 | 설명 |
|--------|------|
| `target_group_arns` | Target Group 키-ARN 맵 |
| `target_group_arn_suffixes` | Target Group 키-ARN Suffix 맵 (CloudWatch 메트릭용) |
| `target_group_ids` | Target Group 키-ID 맵 |
| `target_group_names` | Target Group 키-이름 맵 |

### Listener Outputs

| 출력명 | 설명 |
|--------|------|
| `http_listener_arns` | HTTP Listener 키-ARN 맵 |
| `http_listener_ids` | HTTP Listener 키-ID 맵 |
| `https_listener_arns` | HTTPS Listener 키-ARN 맵 |
| `https_listener_ids` | HTTPS Listener 키-ID 맵 |

### Listener Rule Outputs

| 출력명 | 설명 |
|--------|------|
| `listener_rule_arns` | Listener Rule 키-ARN 맵 |
| `listener_rule_ids` | Listener Rule 키-ID 맵 |

## 생성되는 리소스

- `aws_lb`: Application Load Balancer
- `aws_lb_target_group`: Target Group (target_groups 맵에 정의된 각 항목마다 생성)
- `aws_lb_listener`: HTTP Listener (http_listeners 맵에 정의된 각 항목마다 생성)
- `aws_lb_listener`: HTTPS Listener (https_listeners 맵에 정의된 각 항목마다 생성)
- `aws_lb_listener_rule`: Listener Rule (listener_rules 맵에 정의된 각 항목마다 생성)

## 주의사항

- ALB는 최소 2개 이상의 가용영역에 걸쳐 있는 서브넷이 필요합니다
- HTTPS Listener 사용 시 ACM 인증서 ARN이 필수입니다
- Lambda Target Type은 HTTP 프로토콜만 지원합니다
- Health Check timeout은 interval보다 작아야 합니다
- Listener Rule의 priority는 1-50000 범위이며 중복될 수 없습니다
- 기본 SSL 정책은 TLS 1.3을 지원하는 최신 정책입니다 (ELBSecurityPolicy-TLS13-1-2-2021-06)

## 버전 요구사항

- Terraform >= 1.0
- AWS Provider >= 4.0

## 라이선스

MIT

## 작성자

Platform Team
