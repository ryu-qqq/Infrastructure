# OpenSearch ISM 정책 추가 요청서

> **긴급도**: Critical - 현재 전체 서비스 로그 수집 중단 상태
> **요청일**: 2026-02-25
> **요청자**: 백엔드팀
> **대상 클러스터**: `prod-obs-opensearch`

---

## 1. 현재 문제 상황

### 증상

프로덕션 및 스테이지 환경의 **모든 서비스 로그가 OpenSearch에 수집되지 않고 있습니다.**

Lambda `prod-log-router`가 OpenSearch에 인덱싱을 시도하지만, 샤드 한도 초과로 인해 새 인덱스 생성이 불가하여 100% 에러가 발생하고 있습니다.

### 에러 메시지

```
this action would add [10] total shards, but this cluster currently has [995]/[1000] maximum shards open
```

### 영향 범위

| 항목 | 상태 |
|------|------|
| Prod 로그 수집 | 중단 |
| Stage 로그 수집 | 중단 |
| CloudWatch Logs | 정상 (로그 원본은 보존됨) |
| OpenSearch Dashboards | 새 로그 검색 불가 |

Prod와 Stage가 동일한 OpenSearch 클러스터(`prod-obs-opensearch`)를 사용하고 있어, 양쪽 환경 모두 동일한 영향을 받고 있습니다.

---

## 2. 근본 원인 분석

### 인덱스 증가 구조

현재 로그 인덱스는 일별로 서비스마다 새로 생성되는 패턴입니다.

```
인덱스 네이밍: logs-{서비스명}-YYYY-MM-DD

예시:
  logs-gateway-2026-02-25
  logs-authhub-2026-02-25
  logs-commerce-2026-02-25
  ...
```

### 샤드 소비 계산

| 항목 | 값 |
|------|-----|
| 인덱스당 Primary Shard | 5개 |
| 인덱스당 Replica Shard | 5개 (replica: 1) |
| 인덱스당 총 샤드 | **10개** |
| 일 서비스당 샤드 소비 | **10개** |
| 서비스 수 (예: 5개) | 하루 **50개** 샤드 소비 |

### ISM 정책 부재

**ISM(Index State Management) 정책이 설정되어 있지 않아**, 오래된 인덱스가 자동 삭제되지 않습니다. 인덱스가 계속 누적되어 클러스터 샤드 한도(1,000)에 도달한 것이 근본 원인입니다.

### 클러스터 스펙

| 항목 | 값 |
|------|-----|
| 인스턴스 타입 | t3.medium.search |
| 노드 수 | 1대 |
| 스토리지 | 50GB gp3 |
| 최대 샤드 수 | 1,000 |
| 현재 샤드 수 | **995** |

---

## 3. 즉시 조치 필요 (긴급)

> 이 작업을 먼저 수행해야 로그 수집이 재개됩니다.

### 3.1 삭제 대상 인덱스 확인

OpenSearch Dashboards Dev Tools 또는 API로 현재 인덱스 목록을 확인합니다.

```
GET /_cat/indices/logs-*?v&s=index
```

출력 예시:

```
health status index                        pri rep docs.count store.size
green  open   logs-gateway-2026-01-01        5   1      50000     25mb
green  open   logs-gateway-2026-01-02        5   1      48000     24mb
...
```

### 3.2 오래된 인덱스 삭제

30일 이상 된 인덱스를 삭제하여 샤드를 확보합니다. 아래는 1월 데이터 전체를 삭제하는 예시입니다.

```
DELETE /logs-*-2026-01-*
```

필요한 경우 더 오래된 데이터도 삭제합니다.

```
DELETE /logs-*-2025-*
```

### 3.3 삭제 후 확인

```
GET /_cluster/health
```

확인 항목:
- `active_shards` 값이 대폭 감소했는지 확인
- `status`가 `green`인지 확인

```
GET /_cat/shards?v&h=index,shard,prirep,state
```

### 3.4 로그 수집 재개 확인

인덱스 삭제 후 Lambda `prod-log-router`가 새 인덱스를 정상 생성하는지 확인합니다.

```
# Lambda 실행 로그 확인 (CloudWatch)
Log Group: /aws/lambda/prod-log-router

# 확인 항목:
# - documentsIndexed > 0 인지
# - documentErrors 가 0 인지
```

---

## 4. 영구 조치: ISM 정책 추가

### 4.1 정책 개요

| 상태 | 기간 | 동작 |
|------|------|------|
| HOT | 0-7일 | 활성 상태, 읽기/쓰기 가능 |
| DELETE | 14일 이후 | 인덱스 자동 삭제 |

### 4.2 ISM 정책 JSON

OpenSearch API로 직접 생성하는 경우:

```json
PUT _plugins/_ism/policies/logs-lifecycle-policy
{
  "policy": {
    "policy_id": "logs-lifecycle-policy",
    "description": "logs-* 인덱스 14일 후 자동 삭제",
    "default_state": "hot",
    "states": [
      {
        "name": "hot",
        "actions": [],
        "transitions": [
          {
            "state_name": "delete",
            "conditions": {
              "min_index_age": "14d"
            }
          }
        ]
      },
      {
        "name": "delete",
        "actions": [
          {
            "delete": {}
          }
        ],
        "transitions": []
      }
    ],
    "ism_template": [
      {
        "index_patterns": ["logs-*"],
        "priority": 100
      }
    ]
  }
}
```

`ism_template`의 `index_patterns`에 `logs-*`를 지정하면, 이후 새로 생성되는 모든 `logs-*` 인덱스에 자동으로 이 정책이 적용됩니다.

### 4.3 기존 인덱스에 정책 적용

새로 생성된 정책은 기존 인덱스에 자동 적용되지 않습니다. 기존 인덱스에도 정책을 적용하려면 아래 API를 실행합니다.

```json
POST _plugins/_ism/add/logs-*
{
  "policy_id": "logs-lifecycle-policy"
}
```

### 4.4 Terraform 리소스 (Infrastructure 레포에 추가)

파일 위치: `infrastructure/terraform/environments/prod/logging/opensearch.tf`

```hcl
resource "opensearch_ism_policy" "logs_lifecycle" {
  policy_id = "logs-lifecycle-policy"

  body = jsonencode({
    policy = {
      policy_id     = "logs-lifecycle-policy"
      description   = "logs-* 인덱스 14일 후 자동 삭제"
      default_state = "hot"
      states = [
        {
          name    = "hot"
          actions = []
          transitions = [
            {
              state_name = "delete"
              conditions = {
                min_index_age = "14d"
              }
            }
          ]
        },
        {
          name = "delete"
          actions = [
            {
              delete = {}
            }
          ]
          transitions = []
        }
      ]
      ism_template = [
        {
          index_patterns = ["logs-*"]
          priority       = 100
        }
      ]
    }
  })
}
```

Terraform provider 설정에 OpenSearch provider가 필요합니다. 이미 설정되어 있지 않다면 아래를 참고합니다.

```hcl
terraform {
  required_providers {
    opensearch = {
      source  = "opensearch-project/opensearch"
      version = "~> 2.0"
    }
  }
}

provider "opensearch" {
  url         = aws_opensearch_domain.prod_obs.endpoint
  healthcheck = false
}
```

---

## 5. 추가 권장 사항

### 5.1 인덱스 Primary Shard 수 축소

현재 인덱스당 primary shard가 5개로 설정되어 있습니다. t3.medium 1대 구성의 소형 클러스터에서는 과도한 설정입니다.

| 설정 | 현재 | 권장 |
|------|------|------|
| `number_of_shards` | 5 | **1** |
| `number_of_replicas` | 1 | **0** |
| 인덱스당 총 샤드 | 10 | **1** |

단일 노드 클러스터에서 replica는 같은 노드에 할당될 수 없어 `unassigned` 상태가 됩니다. replica를 0으로 설정하는 것이 적절합니다.

### 5.2 Lambda log-router 인덱스 생성 설정 변경

Lambda `prod-log-router`에서 인덱스를 생성할 때 아래 설정을 추가합니다.

파일 위치: `infrastructure/lambda/log-router/lambda_function.py`

```python
# 인덱스 생성 시 settings 추가
index_settings = {
    "settings": {
        "number_of_shards": 1,
        "number_of_replicas": 0
    }
}
```

이 변경으로 하루 서비스당 샤드 소비가 10개에서 1개로 줄어듭니다.

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 인덱스당 샤드 | 10개 | 1개 |
| 일 5개 서비스 기준 | 50개/일 | 5개/일 |
| 14일간 누적 샤드 | 700개 | 70개 |
| 샤드 한도 대비 여유 | 부족 | 충분 |

### 5.3 장기 검토 사항

- 클러스터 스케일업: 노드 수 증가 또는 인스턴스 타입 업그레이드 검토
- Prod/Stage 클러스터 분리: 환경별 독립 클러스터 운영으로 장애 격리
- OpenSearch Serverless 전환: 샤드 관리 부담 제거, 사용량 기반 과금

---

## 6. 관련 파일 위치

| 파일 | 경로 |
|------|------|
| OpenSearch Terraform | `infrastructure/terraform/environments/prod/logging/opensearch.tf` |
| Lambda log-router | `infrastructure/lambda/log-router/lambda_function.py` |
| Kinesis 설정 | `infrastructure/terraform/environments/prod/logging/kinesis-log-stream.tf` |
| 구독 필터 모듈 | `infrastructure/terraform/modules/log-subscription-filter-v2/` |

---

## 7. 진단 데이터 (AWS 조사 결과)

2026-02-25 기준 각 컴포넌트별 상태를 조사한 결과입니다.

### 7.1 CloudWatch Log Group

| 항목 | 상태 |
|------|------|
| Prod 로그 그룹 | 정상 수집 중 |
| Stage 로그 그룹 | 정상 수집 중 |

CloudWatch Logs 자체는 정상 동작하고 있으며, 로그 원본 데이터는 보존되고 있습니다.

### 7.2 Kinesis Data Stream

| 항목 | 값 |
|------|-----|
| Stream 이름 | `prod-cloudwatch-logs` |
| 상태 | **ACTIVE** |
| 용량 모드 | ON_DEMAND |
| 샤드 수 | 4 |

Kinesis Stream은 정상 동작 중입니다.

### 7.3 Lambda `prod-log-router`

| 항목 | 값 |
|------|-----|
| 실행 상태 | 실행됨 (트리거 정상) |
| 인덱싱 성공 | **0건** (`documentsIndexed: 0`) |
| 인덱싱 에러 | **100%** (`documentErrors` only) |
| DLQ 메시지 | **0건** |

Lambda 함수 자체는 정상적으로 호출되지만, OpenSearch로의 인덱싱이 전부 실패하고 있습니다. Lambda가 에러를 내부적으로 처리하고 성공을 반환하기 때문에 DLQ로 메시지가 전달되지 않습니다.

### 7.4 OpenSearch 클러스터

| 항목 | 값 |
|------|-----|
| 도메인 이름 | `prod-obs-opensearch` |
| 인스턴스 타입 | t3.medium.search |
| 노드 수 | 1 |
| 스토리지 | 50GB gp3 |
| Processing | False |
| 클러스터 상태 | 정상 (샤드 한도만 초과) |
| 현재 샤드 수 | **995 / 1,000** |

---

## 8. 작업 체크리스트

### 긴급 조치 (즉시)

- [ ] `GET /_cat/indices/logs-*?v&s=index`로 인덱스 목록 확인
- [ ] 30일 이상 된 인덱스 삭제 (`DELETE /logs-*-2026-01-*` 등)
- [ ] `GET /_cluster/health`로 샤드 수 감소 확인
- [ ] Lambda `prod-log-router` 정상 인덱싱 재개 확인

### 영구 조치 (1주 이내)

- [ ] ISM 정책 `logs-lifecycle-policy` 생성 (14일 자동 삭제)
- [ ] 기존 인덱스에 ISM 정책 적용
- [ ] Terraform 코드에 ISM 정책 리소스 추가
- [ ] Lambda log-router 인덱스 설정 변경 (`shards: 1, replicas: 0`)

### 장기 검토

- [ ] Prod/Stage OpenSearch 클러스터 분리 검토
- [ ] 클러스터 스케일업 필요성 평가
- [ ] OpenSearch Serverless 전환 가능성 검토

---

## 9. 문의

- **작성자**: 백엔드팀
- **작성일**: 2026-02-25
- **관련 서비스**: 전체 (Prod/Stage 모든 서비스 로그 수집에 영향)
