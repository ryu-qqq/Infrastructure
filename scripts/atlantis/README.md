# Atlantis 운영 스크립트

Atlantis 서버 관리를 위한 유틸리티 스크립트 모음입니다.

## 스크립트 목록

### 1. restart-atlantis.sh
Atlantis ECS 서비스를 재시작합니다.

```bash
# 사용법
./restart-atlantis.sh [환경]

# 예시
./restart-atlantis.sh prod
```

**사용 시나리오**:
- Atlantis가 응답하지 않을 때
- 설정 변경 후 재시작이 필요할 때
- 메모리 누수 등으로 인한 성능 저하 시

### 2. check-atlantis-health.sh
Atlantis의 전반적인 상태를 점검합니다.

```bash
# 사용법
./check-atlantis-health.sh [환경]

# 예시
./check-atlantis-health.sh prod
```

**확인 항목**:
- ECS Service 상태 (실행 중인 Task 수)
- Running Tasks 상태 및 헬스
- ALB Target Health 상태
- 최근 10분간 에러 로그
- 최근 1시간 활동 통계 (Webhook, Plan, Apply 횟수)

### 3. monitor-atlantis-logs.sh
Atlantis 로그를 실시간으로 모니터링합니다.

```bash
# 사용법
./monitor-atlantis-logs.sh [환경] [필터]

# 예시
./monitor-atlantis-logs.sh prod                  # 전체 로그
./monitor-atlantis-logs.sh prod error            # 에러 로그만
./monitor-atlantis-logs.sh prod FileFlow         # FileFlow 관련 로그
./monitor-atlantis-logs.sh prod "terraform plan" # Plan 실행 로그
```

**사용 시나리오**:
- 실시간으로 Atlantis 동작 확인
- 특정 레포지토리의 작업 모니터링
- 에러 발생 여부 감시

### 4. export-atlantis-logs.sh
Atlantis 로그를 파일로 내보냅니다.

```bash
# 사용법
./export-atlantis-logs.sh [환경] [시간범위]

# 예시
./export-atlantis-logs.sh prod 24h  # 최근 24시간
./export-atlantis-logs.sh prod 7d   # 최근 7일
./export-atlantis-logs.sh prod 1h   # 최근 1시간
```

**출력 파일**:
- `atlantis-{환경}-{타임스탬프}.log` - 전체 로그 (short format)
- `atlantis-{환경}-errors-{타임스탬프}.log` - 에러 로그만
- `atlantis-{환경}-{타임스탬프}.json` - JSON 형식 (분석용)

**사용 시나리오**:
- 문제 발생 시 로그 백업
- 장기 분석을 위한 로그 수집
- 외부 도구로 로그 분석

## 일반적인 운영 시나리오

### 시나리오 1: Atlantis가 응답하지 않을 때

```bash
# 1. 헬스체크로 상태 확인
./check-atlantis-health.sh prod

# 2. 에러 로그 확인
./monitor-atlantis-logs.sh prod error

# 3. 문제가 지속되면 재시작
./restart-atlantis.sh prod

# 4. 재시작 후 다시 헬스체크
sleep 120  # 2분 대기
./check-atlantis-health.sh prod
```

### 시나리오 2: 특정 PR의 Plan이 실패할 때

```bash
# 1. 해당 레포지토리 로그 확인
./monitor-atlantis-logs.sh prod "repo-name"

# 2. 또는 특정 PR 번호로 검색
./monitor-atlantis-logs.sh prod "pull=42"

# 3. 에러 로그 수집
./export-atlantis-logs.sh prod 1h

# 4. 로그 분석
grep "error" logs/atlantis-prod-errors-*.log
```

### 시나리오 3: 정기 헬스체크 (매일 오전)

```bash
#!/bin/bash
# daily-health-check.sh

echo "=== 일일 Atlantis 헬스체크 ==="
echo "시간: $(date)"
echo ""

# 헬스체크 실행
./check-atlantis-health.sh prod

# 어제 로그 백업
./export-atlantis-logs.sh prod 24h

echo ""
echo "✅ 일일 헬스체크 완료"
```

### 시나리오 4: 사고 조사 (Incident Investigation)

```bash
# 1. 문제 발생 시점의 로그 수집
./export-atlantis-logs.sh prod 24h

# 2. 에러 로그 추출 및 분석
cd logs
grep -i "error\|fatal\|panic" atlantis-prod-*.log > incident-errors.log

# 3. 시간별 에러 빈도 분석
cat incident-errors.log | cut -d' ' -f1-2 | uniq -c

# 4. 특정 레포지토리 관련 로그만 필터링
grep "FileFlow" atlantis-prod-*.log > fileflow-incident.log
```

## 권한 요구사항

이 스크립트들을 실행하려면 다음 AWS IAM 권한이 필요합니다:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "ecs:UpdateService",
        "elasticloadbalancing:DescribeTargetHealth",
        "logs:FilterLogEvents",
        "logs:GetLogEvents",
        "logs:TailLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

## 문제 해결

### "command not found" 에러
```bash
# 스크립트에 실행 권한 부여
chmod +x *.sh
```

### "Access Denied" 에러
```bash
# AWS 자격증명 확인
aws sts get-caller-identity

# 필요한 권한이 있는지 확인
aws iam get-user
```

### 로그가 출력되지 않음
```bash
# 로그 그룹 존재 확인
aws logs describe-log-groups \
  --log-group-name-prefix "/ecs/atlantis" \
  --region ap-northeast-2

# 최근 로그 스트림 확인
aws logs describe-log-streams \
  --log-group-name "/ecs/atlantis-prod" \
  --order-by LastEventTime \
  --descending \
  --max-items 5 \
  --region ap-northeast-2
```

## 참고 자료

- [Atlantis 운영 가이드](/claudedocs/atlantis-operations-guide.md)
- [AWS ECS CLI 참조](https://docs.aws.amazon.com/cli/latest/reference/ecs/)
- [AWS CloudWatch Logs CLI 참조](https://docs.aws.amazon.com/cli/latest/reference/logs/)
