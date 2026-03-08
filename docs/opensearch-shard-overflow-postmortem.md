# OpenSearch 샤드 한도 초과 장애 분석

> **작성일**: 2026-02-25
> **대상**: `prod-obs-opensearch` 클러스터
> **상태**: 해결 완료

---

## 1. 샤드(Shard)란?

OpenSearch에서 **인덱스(index)**는 데이터를 저장하는 논리적 단위입니다. 그런데 인덱스 하나를 통째로 하나의 덩어리로 저장하지 않고, 내부적으로 여러 조각으로 나누어 저장합니다. 이 조각 하나하나가 **샤드(shard)**입니다.

```
인덱스 (logs-gateway-2026-02-25)
├── Primary Shard 0  ← 데이터 원본 조각
├── Primary Shard 1
├── Primary Shard 2
├── Primary Shard 3
├── Primary Shard 4
├── Replica Shard 0  ← Primary 0의 복제본 (다른 노드에 저장)
├── Replica Shard 1
├── Replica Shard 2
├── Replica Shard 3
└── Replica Shard 4
```

### Primary Shard vs Replica Shard

| 구분 | 역할 | 특징 |
|------|------|------|
| **Primary Shard** | 데이터 원본 저장 | 쓰기/읽기 모두 처리 |
| **Replica Shard** | Primary의 복제본 | 읽기 분산 + 장애 복구용, **반드시 다른 노드**에 배치 |

핵심은 Replica Shard는 **반드시 Primary와 다른 노드에 저장**되어야 한다는 점입니다.

---

## 2. 우리 클러스터의 구성

```
prod-obs-opensearch
├── 인스턴스: t3.medium.search × 1대 (단일 노드)
├── 스토리지: 50GB gp3
└── 최대 샤드 수: 1,000개
```

**단일 노드 클러스터**입니다. 노드가 1대뿐이므로 Replica Shard를 배치할 다른 노드가 없습니다. 그런데도 Replica를 1로 설정하면 어떻게 될까요?

```
Replica Shard → 배치할 다른 노드 없음 → "unassigned" 상태로 대기
```

Replica가 실제로 동작하지 않더라도, OpenSearch는 이것을 **샤드 수에 포함하여 카운트**합니다. 즉 공간만 차지하고 아무 역할도 못하는 유령 샤드가 됩니다.

---

## 3. 장애의 원인: 샤드가 어떻게 1,000개에 도달했는가

### 3.1 인덱스 생성 패턴

Lambda `prod-log-router`는 매일 서비스별로 새 인덱스를 생성합니다.

```
logs-gateway-2026-02-25
logs-authhub-2026-02-25
logs-commerce-2026-02-25
logs-crawlinghub-2026-02-25
logs-atlantis-2026-02-25
```

### 3.2 인덱스당 샤드 소비 (변경 전)

인덱스 생성 시 별도 설정이 없었기 때문에 OpenSearch 기본값이 적용되었습니다.

```
기본값: number_of_shards = 5, number_of_replicas = 1

인덱스 1개당:
  Primary Shard  = 5개
  Replica Shard  = 5개 (= 5 primary × replica 1)
  ─────────────────────
  총 샤드        = 10개
```

### 3.3 일별 샤드 누적 계산

```
하루 생성 인덱스: 5개 (서비스 5개)
하루 소비 샤드:   5개 인덱스 × 10개 샤드 = 50개/일
```

### 3.4 ISM 정책 부재 → 인덱스 무한 누적

**ISM(Index State Management) 정책이 없었습니다.** 오래된 인덱스를 자동으로 삭제하는 규칙이 없으니, 생성된 인덱스는 수동으로 지우지 않는 한 영원히 남아있습니다.

```
1일차:   50개 샤드
2일차:  100개 샤드
3일차:  150개 샤드
...
20일차: 1,000개 샤드 ← 한도 도달
```

**약 20일 만에 샤드 한도 1,000개에 도달합니다.**

### 3.5 한도 도달 → 새 인덱스 생성 불가 → 로그 수집 중단

```
Lambda가 logs-gateway-2026-02-25 인덱스를 생성하려고 시도
    ↓
OpenSearch: "this action would add [10] total shards,
            but this cluster currently has [995]/[1000] maximum shards open"
    ↓
인덱스 생성 실패 → Bulk indexing 실패 → 로그 수집 중단
```

### 3.6 요약: 장애 발생 흐름

```
인덱스당 샤드 10개 (과도한 기본값)
    +
ISM 정책 없음 (인덱스 무한 누적)
    +
단일 노드 클러스터 (샤드 한도 1,000개)
    =
약 20일 만에 샤드 한도 초과 → 전체 로그 수집 중단
```

---

## 4. 무엇을 바꿨는가

### 4.1 ISM 정책 추가 (근본 원인 해결)

인덱스가 무한히 쌓이는 것이 근본 원인이었으므로, **14일 후 자동 삭제** 정책을 추가했습니다.

```
생성 후 0~14일: HOT 상태 (정상 읽기/쓰기)
생성 후 14일~:  자동 삭제
```

이제 인덱스는 최대 14일치만 유지됩니다. 더 이상 무한으로 쌓이지 않습니다.

### 4.2 Index Template 추가 (샤드 수 최적화)

새로 생성되는 `logs-*` 인덱스에 자동 적용되는 템플릿을 추가했습니다.

```
변경 전: number_of_shards = 5, number_of_replicas = 1 → 인덱스당 10개 샤드
변경 후: number_of_shards = 1, number_of_replicas = 0 → 인덱스당 1개 샤드
```

- **shards 5 → 1**: 하루 로그량이 t3.medium 단일 노드에서 shard 1개로 충분히 처리 가능한 수준이므로 5개는 과도했습니다.
- **replicas 1 → 0**: 노드가 1대뿐이라 replica는 어차피 배치될 수 없어 의미가 없습니다.

### 4.3 Lambda 코드 수정 (이중 안전장치)

Lambda `prod-log-router`에서 새 인덱스를 생성할 때도 동일한 설정(`shards=1, replicas=0`)을 명시하도록 변경했습니다. Index Template이 있으므로 사실상 이중 보호입니다.

---

## 5. 변경 전 vs 변경 후 비교

### 샤드 소비량

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 인덱스당 샤드 | 10개 | **1개** |
| 하루 소비 (5개 서비스) | 50개 | **5개** |
| 14일 누적 | 700개 | **70개** |
| 샤드 한도 대비 (1,000) | 70% 사용 (위험) | **7% 사용 (안전)** |

### 인덱스 수명

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 인덱스 삭제 방식 | 없음 (수동 삭제만 가능) | **14일 후 자동 삭제** |
| 최대 인덱스 수 | 무제한 (계속 증가) | **최대 70개** (14일 × 5서비스) |
| 최대 샤드 수 | 무제한 (계속 증가) | **최대 70개** |

### 한도 초과까지 걸리는 시간

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 1,000 샤드 도달 | **약 20일** | **도달 불가** (최대 70개) |

---

## 6. 적용된 리소스 목록

| 리소스 | 파일 | 역할 |
|--------|------|------|
| `opensearch_ism_policy.logs_lifecycle` | `opensearch.tf` | 14일 자동 삭제 정책 |
| `opensearch_index_template.logs` | `opensearch.tf` | shards=1, replicas=0 템플릿 |
| `aws_lambda_function.log_router` | `lambda_function.py` | 인덱스 생성 시 최적화 설정 |

---

## 7. 교훈

1. **ISM 정책은 OpenSearch 운영의 필수 요소입니다.** 시계열 데이터(로그, 메트릭)를 다루는 클러스터에서는 인덱스 생성 시점부터 삭제 정책이 함께 설정되어야 합니다.

2. **클러스터 스펙에 맞는 샤드 설정이 필요합니다.** 단일 노드 소형 클러스터에서 기본값(primary 5, replica 1)은 과도합니다. 노드 수, 데이터 볼륨, 쿼리 패턴을 고려하여 적절한 값을 설정해야 합니다.

3. **콘솔 수동 설정은 Terraform 코드에 반영해야 합니다.** 이번 작업 중 콘솔에서 추가된 `cloudfront-to-opensearch-lambda-role` 접근 권한이 Terraform 코드에 없어 apply 시 삭제될 뻔했습니다. 인프라 변경은 항상 코드에 반영하여 drift를 방지해야 합니다.
