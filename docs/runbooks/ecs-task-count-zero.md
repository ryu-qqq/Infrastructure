# ECS Task Count Zero Runbook

## 알람 정보
- **심각도**: Critical (P0)
- **대상 리소스**: ECS Cluster
- **메트릭**: `DesiredTaskCount`
- **임계값**: 0개 (1분 지속)
- **대응 시간**: 즉시 (5분 이내)

## 증상
모든 ECS 태스크가 중단되어 서비스 다운 상태입니다. 사용자는 서비스에 접근할 수 없습니다.

## 즉시 대응 절차

### 1. 긴급 복구
```bash
# 서비스 desired count 확인
aws ecs describe-services \
  --cluster prod-atlantis-cluster \
  --services atlantis

# Desired count가 0이면 즉시 복구
aws ecs update-service \
  --cluster prod-atlantis-cluster \
  --service atlantis \
  --desired-count 2

# 태스크 시작 상태 모니터링
watch -n 5 'aws ecs list-tasks --cluster prod-atlantis-cluster --desired-status RUNNING'
```

### 2. 실패 원인 확인
```bash
# 서비스 이벤트 확인
aws ecs describe-services \
  --cluster prod-atlantis-cluster \
  --services atlantis \
  --query 'services[0].events[:10]'

# 중단된 태스크 확인
aws ecs list-tasks \
  --cluster prod-atlantis-cluster \
  --desired-status STOPPED \
  --query 'taskArns[:5]' | \
  xargs -I {} aws ecs describe-tasks --cluster prod-atlantis-cluster --tasks {}
```

## 일반적인 원인
1. **컨테이너 헬스체크 실패**
2. **리소스 부족** (CPU/Memory)
3. **잘못된 배포**
4. **IAM 권한 문제**
5. **이미지 풀 실패**

## 관련 대시보드
- [Grafana ECS Dashboard](https://g-XXXXXXXXX.grafana-workspace.ap-northeast-2.amazonaws.com/d/ecs-overview)

## 에스컬레이션
- **즉시**: All hands on deck - Platform Team, Engineering Lead, CTO
