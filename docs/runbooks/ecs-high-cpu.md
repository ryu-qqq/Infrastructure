# ECS High CPU Runbook

## 알람 정보
- **심각도**: Warning (P1)
- **대상 리소스**: ECS Cluster
- **메트릭**: `CPUUtilization`
- **임계값**: 80% 이상 (10분 지속)
- **대응 시간**: 30분 이내

## 증상
ECS 태스크의 CPU 사용률이 80%를 초과하여 10분 이상 지속되고 있습니다. 이는 다음과 같은 상황을 나타낼 수 있습니다:
- 트래픽 급증으로 인한 부하 증가
- 비효율적인 코드 실행
- 무한 루프 또는 CPU 집약적 작업
- 리소스 제한 설정 부족

## 영향 범위
- **성능 저하**: API 응답 시간 증가 가능성
- **서비스 안정성**: CPU 고갈 시 태스크 중단 위험
- **사용자 영향**: 느린 응답 속도로 인한 사용자 경험 저하

## 즉시 대응 절차

### 1. 현재 상태 확인
```bash
# ECS 클러스터 상태 확인
aws ecs describe-clusters --clusters prod-atlantis-cluster

# 실행 중인 태스크 확인
aws ecs list-tasks --cluster prod-atlantis-cluster

# 태스크 상세 정보 확인
aws ecs describe-tasks --cluster prod-atlantis-cluster --tasks <task-arn>
```

### 2. 메트릭 분석
- **Grafana 대시보드 확인**:
  - URL: [AMG Workspace](https://g-XXXXXXXXX.grafana-workspace.ap-northeast-2.amazonaws.com)
  - 대시보드: ECS Service Dashboard
  - 확인 항목: CPU 사용률 추세, 태스크 개수, 네트워크 I/O

- **CloudWatch Metrics 확인**:
  ```bash
  aws cloudwatch get-metric-statistics \
    --namespace ECS/ContainerInsights \
    --metric-name CPUUtilization \
    --dimensions Name=ClusterName,Value=prod-atlantis-cluster \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average
  ```

### 3. 로그 분석
```bash
# ECS 태스크 로그 확인
aws logs tail /aws/ecs/atlantis --follow

# 에러 패턴 검색
aws logs filter-log-events \
  --log-group-name /aws/ecs/atlantis \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s)000
```

### 4. 즉시 조치

#### 트래픽 급증인 경우:
```bash
# Auto Scaling 설정 확인
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs

# 수동 스케일 아웃 (필요시)
aws ecs update-service \
  --cluster prod-atlantis-cluster \
  --service atlantis \
  --desired-count 3  # 현재 개수 + 1
```

#### 애플리케이션 문제인 경우:
```bash
# 문제 태스크 재시작
aws ecs stop-task \
  --cluster prod-atlantis-cluster \
  --task <task-arn> \
  --reason "High CPU usage - manual restart"

# 새 태스크가 정상적으로 시작되는지 확인
aws ecs describe-tasks --cluster prod-atlantis-cluster --tasks <new-task-arn>
```

## 근본 원인 분석

### 일반적인 원인들:
1. **트래픽 증가**
   - 로그에서 요청 수 증가 패턴 확인
   - ALB 메트릭에서 `RequestCount` 증가 확인

2. **비효율적인 쿼리**
   - RDS 성능 인사이트 확인
   - Slow query 로그 분석

3. **메모리 누수로 인한 가비지 컬렉션**
   - 메모리 사용률 동시 확인
   - 힙 덤프 분석 (필요시)

4. **무한 루프 또는 데드락**
   - 애플리케이션 로그에서 반복 패턴 확인
   - 스레드 덤프 분석

5. **외부 API 호출 지연**
   - 외부 API 응답 시간 확인
   - 타임아웃 설정 검토

### 분석 도구:
- **AWS X-Ray**: 분산 트레이싱으로 병목 구간 식별
- **CloudWatch Container Insights**: 컨테이너 수준 메트릭
- **Application Performance Monitoring (APM)**: 애플리케이션 프로파일링

## 예방 조치

### 1. Auto Scaling 정책 개선
```hcl
# Target Tracking Scaling Policy
resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "ecs-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0  # 80%에 도달하기 전에 스케일 아웃
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
```

### 2. 리소스 제한 최적화
- Task Definition에서 CPU 유닛 증가 검토
- CPU 예약(reservation) vs 제한(limit) 재조정

### 3. 코드 최적화
- 프로파일링 도구를 통한 핫스팟 식별
- CPU 집약적 작업의 비동기 처리
- 캐싱 전략 도입

### 4. 모니터링 강화
```hcl
# 70% 수준의 조기 경보 설정
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_early_warning" {
  alarm_name          = "ecs-cpu-early-warning"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_sns_topic.info.arn]
}
```

## 관련 대시보드
- [Grafana ECS Dashboard](https://g-XXXXXXXXX.grafana-workspace.ap-northeast-2.amazonaws.com/d/ecs-overview)
- [CloudWatch ECS Metrics](https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#metricsV2:graph=~();namespace=ECS/ContainerInsights)

## 에스컬레이션
- **Level 1**: Platform Team (Slack: #platform-team)
- **Level 2**: Engineering Lead
- **Level 3**: CTO

## 체크리스트
- [ ] 현재 CPU 사용률 확인
- [ ] 트래픽 패턴 분석
- [ ] 로그에서 에러 패턴 확인
- [ ] 필요시 수동 스케일 아웃 실행
- [ ] 근본 원인 식별
- [ ] 예방 조치 적용
- [ ] 인시던트 포스트모템 작성
