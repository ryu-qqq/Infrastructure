# ECS Memory Critical Runbook

## 알람 정보
- **심각도**: Critical (P0)
- **대상 리소스**: ECS Cluster
- **메트릭**: `MemoryUtilization`
- **임계값**: 95% 이상 (5분 지속)
- **대응 시간**: 즉시 (5분 이내)

## 증상
ECS 태스크의 메모리 사용률이 95%를 초과하여 메모리 고갈 위험 상태입니다. Out Of Memory (OOM) 발생 시 태스크가 강제 종료됩니다.

## 즉시 대응 절차

### 1. 긴급 조치
```bash
# 태스크 개수 즉시 증가
aws ecs update-service \
  --cluster prod-atlantis-cluster \
  --service atlantis \
  --desired-count $(( $(aws ecs describe-services --cluster prod-atlantis-cluster --services atlantis --query 'services[0].desiredCount' --output text) + 1 ))

# 고메모리 태스크 재시작
aws ecs list-tasks --cluster prod-atlantis-cluster | \
  xargs -I {} aws ecs stop-task --cluster prod-atlantis-cluster --task {} --reason "High memory - emergency restart"
```

### 2. 메모리 사용 분석
```bash
# 컨테이너별 메모리 사용률
aws cloudwatch get-metric-statistics \
  --namespace ECS/ContainerInsights \
  --metric-name MemoryUtilization \
  --dimensions Name=ClusterName,Value=prod-atlantis-cluster \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Maximum,Average
```

### 3. 로그 확인
```bash
# OOM killer 이벤트 확인
aws logs filter-log-events \
  --log-group-name /aws/ecs/atlantis \
  --filter-pattern "out of memory"

# 메모리 관련 경고 확인
aws logs filter-log-events \
  --log-group-name /aws/ecs/atlantis \
  --filter-pattern "OutOfMemoryError OR MemoryError"
```

## 근본 원인 분석
1. **메모리 누수**: 애플리케이션 코드의 메모리 누수
2. **대용량 데이터 처리**: 한 번에 큰 데이터를 메모리에 로드
3. **캐시 과다 사용**: 적절하지 않은 캐싱 전략
4. **동시 요청 급증**: 많은 수의 동시 요청 처리

## 예방 조치
1. **메모리 제한 증가**
   ```hcl
   # Task Definition 업데이트
   memory = 2048  # 현재 1024에서 증가
   ```

2. **힙 메모리 모니터링 추가**
   - JVM heap metrics 수집
   - 메모리 프로파일링 도구 적용

3. **스트리밍 처리 도입**
   - 대용량 데이터는 스트리밍으로 처리
   - 페이지네이션 적용

## 관련 대시보드
- [Grafana ECS Dashboard](https://g-XXXXXXXXX.grafana-workspace.ap-northeast-2.amazonaws.com/d/ecs-memory)
- [CloudWatch Container Insights](https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#container-insights)

## 에스컬레이션
- **즉시**: Platform Team Lead
- **30분 이상 지속**: Engineering VP
