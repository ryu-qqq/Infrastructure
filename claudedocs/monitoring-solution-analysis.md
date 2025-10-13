# 중앙 모니터링 시스템 솔루션 분석
# CloudWatch vs Grafana/Prometheus 비교

**분석 날짜**: 2025-10-13
**대상 이슈**: IN-32, IN-33, IN-34, IN-35
**목적**: 중앙 모니터링 시스템 구축을 위한 최적 솔루션 선정

---

## 📊 현재 인프라 현황

### 기존 구성
- **플랫폼**: AWS ECS Fargate
- **로깅**: CloudWatch Logs 사용 중 (`/ecs/atlantis-prod`)
- **네트워크**: VPC Endpoints 설정 완료 (CloudWatch 포함)
- **보안**: IAM 역할 기반 권한 관리
- **서비스**: Atlantis (Terraform 자동화 서버)

### 모니터링 요구사항 (추정)
- ECS 서비스 메트릭 (CPU, 메모리, 네트워크)
- 애플리케이션 로그 집계 및 검색
- 인프라 상태 실시간 모니터링
- 알림 및 이상 탐지
- 통합 대시보드

---

## 🔍 솔루션 비교 분석

## Option 1: AWS CloudWatch 대시보드

### 아키텍처
```
ECS Fargate → CloudWatch Logs → CloudWatch Metrics → CloudWatch Dashboard
                                                    ↓
                                            CloudWatch Alarms → SNS
```

### 장점 ✅

#### 1. **네이티브 통합 및 Zero 인프라**
- AWS 서비스와 완벽 통합
- 별도 서버/컨테이너 불필요
- VPC Endpoint 활용으로 외부 트래픽 없음

#### 2. **즉시 사용 가능**
- 이미 CloudWatch Logs 사용 중
- 추가 설정 최소화
- 빠른 구축 (1-2일)

#### 3. **보안 및 규정 준수**
- IAM 기반 세밀한 권한 제어
- AWS 보안 표준 준수
- 감사 로그 자동 기록 (CloudTrail)

#### 4. **관리 부담 최소화**
- 서버리스 아키텍처
- 자동 스케일링
- 패치/업데이트 불필요

#### 5. **비용 예측 가능**
- 사용량 기반 과금
- 프리티어 혜택
- 예상 비용: $10-50/월 (소규모)

### 단점 ❌

#### 1. **제한적인 시각화**
- 커스텀 대시보드 기능 제한적
- 복잡한 그래프 어려움
- PromQL 같은 강력한 쿼리 언어 부재

#### 2. **멀티 소스 통합 어려움**
- AWS 외부 메트릭 통합 복잡
- 온프레미스 시스템 연동 제한적

#### 3. **고급 기능 부족**
- 복잡한 알림 로직 구현 어려움
- 트레이싱 기능 약함
- 플러그인 생태계 없음

#### 4. **벤더 종속성**
- AWS에 강하게 종속
- 마이그레이션 어려움

### 구현 난이도
- **복잡도**: ⭐ (매우 낮음)
- **구축 시간**: 1-2일
- **유지보수**: ⭐ (매우 낮음)

---

## Option 2: Grafana + Prometheus

### 아키텍처
```
ECS Fargate → Prometheus Exporter → Prometheus Server → Grafana
              ↓                      ↓                    ↓
              CloudWatch Exporter    AlertManager        Dashboard
```

### 장점 ✅

#### 1. **강력한 시각화 및 커스터마이징**
- 무한한 대시보드 커스터마이징
- 수백 가지 시각화 옵션
- 드래그 앤 드롭 대시보드 빌더
- 템플릿 변수, 애니메이션 지원

#### 2. **오픈소스 생태계**
- 활발한 커뮤니티
- 수천 개의 플러그인
- 다양한 데이터 소스 통합
- 벤더 중립적

#### 3. **강력한 쿼리 언어 (PromQL)**
- 복잡한 메트릭 계산
- 시계열 데이터 분석 최적화
- 고급 알림 규칙

#### 4. **멀티 클라우드/하이브리드 지원**
- AWS, GCP, Azure, 온프레미스 통합
- Kubernetes 네이티브 지원
- 확장성 우수

#### 5. **고급 기능**
- 분산 추적 (Tempo 통합)
- 로그 집계 (Loki 통합)
- 알림 라우팅 (AlertManager)

### 단점 ❌

#### 1. **높은 인프라 복잡도**
- Prometheus, Grafana 서버 운영 필요
- ECS/EC2 인스턴스 추가 필요
- 스토리지 관리 (메트릭 데이터)

#### 2. **운영 오버헤드**
- 서버 패치 및 업데이트
- 백업 및 복구 관리
- 모니터링 시스템의 모니터링 필요

#### 3. **학습 곡선**
- PromQL 학습 필요
- Grafana 대시보드 설정 복잡
- 구축 및 운영 전문성 요구

#### 4. **추가 비용**
- **ECS Fargate 비용**:
  - Prometheus: vCPU 0.5, 메모리 1GB → ~$15-25/월
  - Grafana: vCPU 0.25, 메모리 512MB → ~$8-15/월
- **EBS/EFS 스토리지**: ~$5-20/월
- **로드 밸런서** (선택): ~$16/월
- **총 예상**: $45-75/월 (최소 구성)

#### 5. **CloudWatch 통합 추가 작업**
- CloudWatch Exporter 필요
- API 호출 비용 발생
- 실시간성 떨어짐 (폴링 방식)

### 구현 난이도
- **복잡도**: ⭐⭐⭐⭐ (높음)
- **구축 시간**: 1-2주
- **유지보수**: ⭐⭐⭐ (중간-높음)

---

## Option 3: 하이브리드 접근법

### 아키텍처
```
ECS Fargate → CloudWatch Logs/Metrics → CloudWatch Dashboard (기본 모니터링)
              ↓                          ↓
              Prometheus Exporter → Grafana (고급 대시보드)
```

### 특징
- CloudWatch를 기본 모니터링으로 활용
- 필요시 Grafana로 고급 시각화
- CloudWatch Logs Insights를 Grafana에서 쿼리

### 장점
- 점진적 마이그레이션 가능
- 각 도구의 강점 활용
- 비용 최적화 (필요한 부분만)

### 단점
- 이중 관리 필요
- 시스템 복잡도 증가
- 중복 데이터 스토리지

---

## 🎯 의사결정 프레임워크

### 질문 1: 팀 규모와 전문성은?
- **소규모 (1-3명), DevOps 전담 없음** → **CloudWatch 추천**
- **중대규모 (4명+), DevOps 전문** → Grafana/Prometheus 고려

### 질문 2: 모니터링 요구사항 복잡도는?
- **기본 메트릭, 간단한 알림** → **CloudWatch 추천**
- **복잡한 쿼리, 상관 분석, 트레이싱** → Grafana/Prometheus 고려

### 질문 3: 미래 확장 계획은?
- **AWS 단일 클라우드, 소규모 유지** → **CloudWatch 추천**
- **멀티 클라우드, 하이브리드, 대규모 확장** → Grafana/Prometheus 추천

### 질문 4: 예산 제약은?
- **최소 비용, 빠른 구축** → **CloudWatch 추천**
- **투자 여력, 장기적 유연성** → Grafana/Prometheus 고려

### 질문 5: 대시보드 커스터마이징 필요성은?
- **AWS 기본 대시보드로 충분** → **CloudWatch 추천**
- **정교한 시각화, 임원 대시보드** → Grafana/Prometheus 추천

---

## 💡 권장 사항

### 현재 상황 기반 추천: **AWS CloudWatch 대시보드 (Option 1)**

#### 근거:
1. ✅ **이미 CloudWatch 인프라 구축됨** → 즉시 활용 가능
2. ✅ **소규모 인프라** (현재 Atlantis 서버 1개) → 복잡한 모니터링 불필요
3. ✅ **빠른 구축 필요** → 1-2일 내 대시보드 완성
4. ✅ **관리 부담 최소화** → 서버리스 아키텍처
5. ✅ **비용 효율적** → 월 $10-50 vs $45-75+

#### 구현 우선순위:
**Phase 1: CloudWatch 대시보드 (IN-32~35)**
1. ECS 서비스 메트릭 대시보드
2. 애플리케이션 로그 필터 및 인사이트
3. CloudWatch Alarms 설정
4. SNS 알림 통합

**Phase 2: 필요시 확장 (미래)**
- 서비스 증가 시 Grafana 도입 고려
- Prometheus로 커스텀 메트릭 수집
- 하이브리드 모델로 전환

---

## 🚀 CloudWatch 대시보드 구현 계획

### 1단계: 메트릭 수집 설정
```terraform
# cloudwatch-metrics.tf
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "infrastructure-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      # ECS 서비스 메트릭
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "atlantis-prod"],
            [".", "MemoryUtilization", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = "ap-northeast-2"
          title  = "ECS Service Resources"
        }
      },
      # ALB 메트릭
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime"],
            [".", "RequestCount"],
            [".", "HTTPCode_Target_5XX_Count"]
          ]
          title = "Load Balancer Performance"
        }
      }
    ]
  })
}

# 알림 설정
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "atlantis-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

### 2단계: 로그 인사이트 쿼리
```sql
-- 에러 로그 분석
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(5m)

-- 응답 시간 분석
fields @timestamp, responseTime
| stats avg(responseTime), max(responseTime), min(responseTime) by bin(5m)
```

### 3단계: 알림 통합
- SNS 토픽 생성
- Slack/Email 알림 설정
- PagerDuty 통합 (선택)

---

## 📈 Grafana/Prometheus 도입 시나리오

### 언제 고려해야 하나?

#### 시나리오 1: 서비스 확장
- **조건**: ECS 서비스 5개 이상
- **이유**: 통합 대시보드 필요성 증가
- **시점**: 서비스 3-4개 시점에 검토 시작

#### 시나리오 2: 커스텀 메트릭 필요
- **조건**: 애플리케이션 특화 메트릭 (비즈니스 KPI)
- **이유**: CloudWatch Custom Metrics 비용 높음
- **시점**: 커스텀 메트릭 10개 이상 필요 시

#### 시나리오 3: 멀티 클라우드
- **조건**: GCP/Azure 추가 또는 온프레미스 통합
- **이유**: 통합 모니터링 플랫폼 필요
- **시점**: 멀티 클라우드 계획 확정 시

#### 시나리오 4: 고급 분석 요구
- **조건**: SLO/SLI 추적, 분산 추적 필요
- **이유**: CloudWatch 기능 한계
- **시점**: Observability 성숙도 향상 시

### 마이그레이션 경로
1. CloudWatch 유지하면서 Grafana 추가 (읽기 전용)
2. Prometheus 점진적 도입 (커스텀 메트릭부터)
3. CloudWatch Exporter로 기존 메트릭 통합
4. 완전 전환 (선택 사항)

---

## 💰 비용 비교

### CloudWatch 대시보드
```
- CloudWatch Logs 수집: ~$5/월 (5GB)
- CloudWatch Metrics: ~$3/월 (10 메트릭)
- CloudWatch Alarms: ~$2/월 (5 알람)
- 대시보드: $3/월 (1 대시보드)
- Log Insights 쿼리: ~$5/월
────────────────────────────────────
총 예상: $15-25/월
```

### Grafana + Prometheus
```
- ECS Fargate (Prometheus): ~$20/월
- ECS Fargate (Grafana): ~$12/월
- EBS/EFS 스토리지: ~$10/월
- ALB (선택): ~$16/월
- CloudWatch Exporter API: ~$5/월
- 기존 CloudWatch: ~$15/월 (유지)
────────────────────────────────────
총 예상: $60-90/월
```

### ROI 분석
- **추가 비용**: $40-65/월
- **절감 시간**: 주 2-3시간 (고급 대시보드 활용)
- **Break-even**: 개발자 시급 > $15-20/h 일 때

---

## 🎓 학습 리소스

### CloudWatch 대시보드
- [AWS CloudWatch 공식 문서](https://docs.aws.amazon.com/cloudwatch/)
- [Terraform aws_cloudwatch_dashboard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard)
- [CloudWatch Logs Insights 쿼리 문법](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)

### Grafana + Prometheus (미래 참고)
- [Prometheus 시작하기](https://prometheus.io/docs/introduction/overview/)
- [Grafana 튜토리얼](https://grafana.com/tutorials/)
- [AWS ECS에 Prometheus 배포](https://aws.amazon.com/blogs/containers/using-prometheus-metrics-in-amazon-ecs/)

---

## 📝 결론

**현재 단계에서는 AWS CloudWatch 대시보드를 먼저 구축하는 것을 강력히 권장합니다.**

### 이유:
1. ✅ 빠른 가치 제공 (1-2일 내 구축)
2. ✅ 최소 비용으로 시작 ($15-25/월)
3. ✅ 이미 구축된 인프라 활용
4. ✅ 관리 부담 최소화
5. ✅ 추후 확장 가능 (하이브리드 모델)

### 다음 단계:
- IN-32: ECS 메트릭 대시보드 구축
- IN-33: 로그 인사이트 쿼리 설정
- IN-34: CloudWatch Alarms 설정
- IN-35: SNS 알림 통합

**Grafana/Prometheus는 서비스가 5개 이상으로 확장되거나, 복잡한 커스텀 메트릭이 필요해질 때 재검토하는 것을 권장합니다.**

---

## 📞 Q&A

### Q1: CloudWatch에서 Grafana로 나중에 마이그레이션 가능한가요?
**A**: 네, 가능합니다. Grafana는 CloudWatch를 데이터 소스로 직접 연결할 수 있어, CloudWatch 메트릭을 Grafana 대시보드에서 시각화할 수 있습니다. 점진적 전환이 가능합니다.

### Q2: Prometheus 없이 Grafana만 사용할 수 있나요?
**A**: 네, Grafana는 CloudWatch를 포함한 여러 데이터 소스를 지원합니다. Prometheus 없이 Grafana + CloudWatch 조합도 가능합니다.

### Q3: 두 솔루션을 동시에 사용하면 어떤가요?
**A**: 가능하지만 관리 복잡도가 증가합니다. 초기에는 CloudWatch로 시작하고, 필요시 Grafana를 추가하여 고급 대시보드를 만드는 하이브리드 접근을 권장합니다.

### Q4: 비용을 절감하려면?
**A**: CloudWatch 대시보드를 먼저 사용하고, 정말 필요한 경우에만 Grafana/Prometheus를 도입하세요. AWS Managed Grafana 서비스도 고려해볼 수 있습니다 (관리 부담 감소).

---

**작성자**: Claude Code
**최종 업데이트**: 2025-10-13
