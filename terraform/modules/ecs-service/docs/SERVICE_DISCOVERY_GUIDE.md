# ECS Service Discovery 사용 가이드

AWS Cloud Map 기반 Service Discovery를 사용하여 ECS 서비스 간 내부 통신을 구성하는 방법입니다.

## 빠른 시작

### 1. SSM에서 Namespace ID 가져오기

```hcl
data "aws_ssm_parameter" "service_discovery_namespace_id" {
  name = "/shared/service-discovery/namespace-id"
}
```

### 2. ECS 모듈에 Service Discovery 설정 추가

```hcl
module "my_service" {
  source = "../../modules/ecs-service"

  name            = "authhub"
  container_port  = 9090
  # ... 기존 설정 ...

  # Service Discovery 설정
  enable_service_discovery           = true
  service_discovery_namespace_id     = data.aws_ssm_parameter.service_discovery_namespace_id.value
  service_discovery_namespace_name   = "connectly.local"
  service_discovery_dns_ttl          = 10
  service_discovery_failure_threshold = 1
}
```

### 3. 결과

```
DNS: authhub.connectly.local
Endpoint: http://authhub.connectly.local:9090
```

## 변수 레퍼런스

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `enable_service_discovery` | bool | `false` | Service Discovery 활성화 |
| `service_discovery_namespace_id` | string | `null` | Cloud Map Namespace ID |
| `service_discovery_namespace_name` | string | `"connectly.local"` | Namespace 이름 |
| `service_discovery_dns_ttl` | number | `10` | DNS TTL (초) |
| `service_discovery_dns_type` | string | `"A"` | DNS 레코드 타입 |
| `service_discovery_routing_policy` | string | `"MULTIVALUE"` | 라우팅 정책 |
| `service_discovery_failure_threshold` | number | `1` | Health Check 실패 임계값 |

## SSM Parameter Store 참조

| Parameter | 설명 |
|-----------|------|
| `/shared/service-discovery/namespace-id` | Namespace ID |
| `/shared/service-discovery/namespace-arn` | Namespace ARN |
| `/shared/service-discovery/namespace-name` | Namespace 이름 |

## 트러블슈팅

### DNS 조회 실패
```bash
# ECS Task 내에서 확인
nslookup authhub.connectly.local
```

### 등록 상태 확인
```bash
aws servicediscovery discover-instances \
  --namespace-name connectly.local \
  --service-name authhub
```

자세한 내용은 [CHANGELOG.md](../CHANGELOG.md)의 v1.1.0 섹션을 참조하세요.
