# ECR (Elastic Container Registry) Terraform 구성

AWS ECR을 사용한 컨테이너 이미지 레지스트리 인프라 구성입니다. 각 서비스별 ECR 리포지토리를 관리하며, KMS 암호화, 이미지 스캔, 라이프사이클 정책을 포함합니다.

## 📋 목차

- [개요](#개요)
- [구성 요소](#구성-요소)
- [사용 방법](#사용-방법)
- [서비스별 리포지토리](#서비스별-리포지토리)
- [보안 고려사항](#보안-고려사항)
- [관련 문서](#관련-문서)

---

## 개요

이 디렉토리는 AWS ECR 리포지토리 인프라를 관리합니다. 각 서비스(FileFlow 등)는 독립적인 서브디렉토리로 구성되어 있으며, 표준화된 보안 및 관리 정책을 적용합니다.

### 주요 특징

- ✅ **KMS 암호화**: 모든 이미지는 고객 관리형 KMS 키로 암호화
- ✅ **자동 이미지 스캔**: 푸시 시 보안 취약점 자동 스캔
- ✅ **라이프사이클 관리**: 이미지 보존 정책으로 스토리지 비용 최적화
- ✅ **크로스 스택 참조**: SSM Parameter Store를 통한 안전한 리소스 참조
- ✅ **표준 태그**: 거버넌스 요구사항 준수 (Owner, CostCenter 등)

---

## 구성 요소

### 디렉토리 구조

```
terraform/ecr/
├── README.md              # 이 파일
├── CHANGELOG.md           # 변경 이력
└── fileflow/              # FileFlow 서비스 ECR
    ├── main.tf            # ECR 리포지토리, 라이프사이클 정책, 접근 정책
    ├── variables.tf       # 입력 변수
    ├── outputs.tf         # 출력값 및 SSM Parameter 저장
    ├── locals.tf          # 로컬 변수 및 태그
    ├── data.tf            # 데이터 소스 (KMS 키, Account ID)
    └── provider.tf        # Provider 설정
```

### 서브디렉토리별 설명

각 서비스는 독립적인 디렉토리로 관리됩니다:

- **fileflow/**: FileFlow 애플리케이션용 ECR 리포지토리

---

## 사용 방법

### 1. 사전 요구사항

- AWS CLI 구성 완료
- Terraform >= 1.5.0
- 적절한 IAM 권한 (ECR, KMS, SSM Parameter Store)
- **의존성**: KMS 키가 SSM Parameter Store에 사전 등록되어야 함
  - `/shared/kms/ecs-secrets-key-arn`

### 2. 새 서비스 ECR 리포지토리 추가

#### Step 1: 서브디렉토리 생성

```bash
# 새 서비스용 디렉토리 생성
cd terraform/ecr
mkdir <service-name>
cd <service-name>
```

#### Step 2: Terraform 파일 작성

기존 `fileflow/` 디렉토리를 템플릿으로 사용:

```bash
# fileflow 디렉토리를 템플릿으로 복사
cp -r ../fileflow/* .

# 서비스명에 맞게 수정
# - locals.tf의 repository_name 변경
# - variables.tf의 기본값 검토
# - outputs.tf의 SSM Parameter 경로 변경
```

#### Step 3: 초기화 및 배포

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

### 3. 기존 리포지토리 관리

#### FileFlow ECR 배포

```bash
cd terraform/ecr/fileflow
terraform init
terraform plan
terraform apply
```

#### 이미지 푸시

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 빌드
docker build -t fileflow:latest .

# 이미지 태그
docker tag fileflow:latest <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/fileflow:latest

# 이미지 푸시
docker push <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/fileflow:latest
```

---

## 서비스별 리포지토리

### FileFlow ECR

**위치**: `terraform/ecr/fileflow/`

**설명**: FileFlow 애플리케이션 컨테이너 이미지 저장소

**주요 리소스**:
- **ECR Repository**: `fileflow`
- **암호화**: KMS (고객 관리형 키)
- **이미지 스캔**: 활성화 (푸시 시)
- **라이프사이클**:
  - `v*` 태그 이미지: 최대 30개 유지
  - 언태그 이미지: 7일 후 자동 삭제

**Variables**:

| 변수 | 설명 | 기본값 | 타입 |
|------|------|--------|------|
| `aws_region` | AWS 리전 | `ap-northeast-2` | string |
| `environment` | 환경 이름 | `prod` | string |
| `owner` | 리소스 소유자 | `platform-team@ryuqqq.com` | string |
| `cost_center` | 비용 센터 | `engineering` | string |
| `lifecycle_stage` | 라이프사이클 단계 | `production` | string |
| `data_class` | 데이터 분류 | `confidential` | string |
| `image_tag_mutability` | 이미지 태그 변경 가능 여부 | `MUTABLE` | string |
| `scan_on_push` | 푸시 시 이미지 스캔 활성화 | `true` | bool |
| `lifecycle_policy_max_image_count` | 최대 이미지 개수 | `30` | number |

**Outputs**:

| 출력 | 설명 |
|------|------|
| `repository_url` | ECR 리포지토리 URL |
| `repository_arn` | ECR 리포지토리 ARN |
| `repository_name` | ECR 리포지토리 이름 |
| `registry_id` | 레지스트리 ID |

**SSM Parameter Exports**:
- `/shared/ecr/fileflow-repository-url`: 리포지토리 URL (다른 스택에서 참조용)

---

## 보안 고려사항

### 1. KMS 암호화

모든 ECR 리포지토리는 **고객 관리형 KMS 키**로 암호화됩니다:

```hcl
encryption_configuration {
  encryption_type = "KMS"
  kms_key         = data.aws_ssm_parameter.ecs-secrets-key-arn.value
}
```

**중요**: KMS 키는 사전에 생성되어 SSM Parameter Store에 저장되어야 합니다.

### 2. 이미지 스캔

푸시 시 자동 이미지 스캔이 활성화되어 있습니다:

```hcl
image_scanning_configuration {
  scan_on_push = true
}
```

**권장사항**:
- 스캔 결과를 정기적으로 검토
- HIGH 및 CRITICAL 취약점은 즉시 수정
- 취약점이 있는 이미지는 프로덕션 배포 금지

### 3. 리포지토리 접근 정책

기본적으로 **동일 AWS 계정 내**에서만 접근 가능합니다:

```hcl
Principal = {
  AWS = [
    "arn:aws:iam::${account_id}:root"
  ]
}
```

**크로스 계정 접근이 필요한 경우**:
- Repository Policy에 대상 계정 ARN 추가
- 대상 계정의 IAM Role/User에 ECR 권한 부여

### 4. 라이프사이클 정책

스토리지 비용 최적화를 위한 자동 이미지 정리:

**정책 1**: 태그된 이미지 (`v*`)
- 최대 30개 유지
- 오래된 이미지부터 자동 삭제

**정책 2**: 언태그 이미지
- 7일 후 자동 삭제

**권장사항**:
- 프로덕션 이미지는 반드시 시맨틱 버전 태그 사용 (예: `v1.0.0`)
- 빌드 중간 이미지는 태그하지 않음 (자동 정리됨)

### 5. SSM Parameter 크로스 스택 참조

직접 리소스 참조 대신 SSM Parameter를 사용합니다:

```hcl
# 다른 스택에서 ECR URL 참조
data "aws_ssm_parameter" "fileflow_ecr" {
  name = "/shared/ecr/fileflow-repository-url"
}
```

**장점**:
- 스택 간 직접 의존성 제거
- 독립적인 배포 가능
- 순환 의존성 방지

### 6. IAM 권한 최소화

**ECR 접근 권한은 최소한으로 제한**:

```hcl
# ❌ 잘못된 예: 과도한 권한
{
  "Effect": "Allow",
  "Action": "ecr:*",
  "Resource": "*"
}

# ✅ 올바른 예: 필요한 권한만 부여
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage"
  ],
  "Resource": "arn:aws:ecr:ap-northeast-2:ACCOUNT_ID:repository/fileflow"
}
```

**ECS Task Role 권한** (Pull만 필요):
```bash
# IAM 정책 확인
aws iam get-role-policy \
  --role-name ecs-task-execution-role \
  --policy-name ecr-pull-policy \
  --region ap-northeast-2
```

**CI/CD Pipeline 권한** (Push 필요):
```hcl
resource "aws_iam_policy" "ecr_push" {
  name = "ecr-push-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:ap-northeast-2:ACCOUNT_ID:repository/fileflow"
      }
    ]
  })
}
```

### 7. 취약점 스캔 모니터링

**스캔 결과 확인 및 알람 설정**:

```bash
# 스캔 결과 확인
aws ecr describe-image-scan-findings \
  --repository-name fileflow \
  --image-id imageTag=latest \
  --region ap-northeast-2 \
  --query 'imageScanFindings.{Critical:findingSeverityCounts.CRITICAL,High:findingSeverityCounts.HIGH,Medium:findingSeverityCounts.MEDIUM}'

# CRITICAL/HIGH 취약점만 필터링
aws ecr describe-image-scan-findings \
  --repository-name fileflow \
  --image-id imageTag=latest \
  --region ap-northeast-2 \
  --query 'imageScanFindings.findings[?severity==`CRITICAL` || severity==`HIGH`]'
```

**EventBridge를 통한 자동 알람**:
```hcl
resource "aws_cloudwatch_event_rule" "ecr_scan_finding" {
  name        = "ecr-critical-vulnerability-found"
  description = "Trigger when ECR finds CRITICAL vulnerabilities"

  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Scan"]
    detail = {
      finding-severity-counts = {
        CRITICAL = [{
          numeric = [">", 0]
        }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.ecr_scan_finding.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}
```

**CI/CD에서 취약점 검증**:
```yaml
# GitHub Actions 예시
- name: Scan for vulnerabilities
  run: |
    SCAN_FINDINGS=$(aws ecr describe-image-scan-findings \
      --repository-name fileflow \
      --image-id imageTag=${{ github.sha }} \
      --region ap-northeast-2 \
      --query 'imageScanFindings.findingSeverityCounts.CRITICAL')

    if [ "$SCAN_FINDINGS" != "null" ] && [ "$SCAN_FINDINGS" -gt 0 ]; then
      echo "❌ CRITICAL vulnerabilities found!"
      exit 1
    fi
```

### 8. 이미지 서명 및 검증

**Docker Content Trust (DCT) 활성화**:

```bash
# 이미지 서명 활성화
export DOCKER_CONTENT_TRUST=1
export DOCKER_CONTENT_TRUST_SERVER=https://notary.docker.io

# 서명된 이미지 Push
docker push 646886795421.dkr.ecr.ap-northeast-2.amazonaws.com/fileflow:v1.0.0

# 서명 검증
docker trust inspect 646886795421.dkr.ecr.ap-northeast-2.amazonaws.com/fileflow:v1.0.0
```

**AWS Signer를 통한 이미지 서명** (엔터프라이즈):
```hcl
resource "aws_signer_signing_profile" "ecr" {
  platform_id = "Notation-OCI-SHA384-ECDSA"
  name        = "ecr-image-signing"

  signature_validity_period {
    value = 5
    type  = "YEARS"
  }
}

# ECS Task Definition에서 서명된 이미지만 허용
resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([{
    image = "646886795421.dkr.ecr.ap-northeast-2.amazonaws.com/fileflow:v1.0.0@sha256:abc123..."
  }])
}
```

### 9. 감사 로그 및 모니터링

**CloudTrail을 통한 ECR API 호출 추적**:

```bash
# ECR 이미지 Pull 이력
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::ECR::Repository \
  --region ap-northeast-2 \
  --max-results 50 \
  --query 'Events[?EventName==`BatchGetImage`]'

# ECR 이미지 Push 이력
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::ECR::Repository \
  --region ap-northeast-2 \
  --max-results 50 \
  --query 'Events[?EventName==`PutImage`]'

# 리포지토리 삭제 시도
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::ECR::Repository \
  --region ap-northeast-2 \
  --max-results 50 \
  --query 'Events[?EventName==`DeleteRepository`]'
```

**CloudWatch Alarms for 비정상 활동**:
```hcl
resource "aws_cloudwatch_log_metric_filter" "ecr_unauthorized_access" {
  name           = "ecr-unauthorized-access"
  log_group_name = "/aws/cloudtrail/logs"

  pattern = "{ ($.eventSource = ecr.amazonaws.com) && ($.errorCode = AccessDenied) }"

  metric_transformation {
    name      = "ECRUnauthorizedAttempts"
    namespace = "ECR/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecr_unauthorized_access" {
  alarm_name          = "ecr-unauthorized-access-attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ECRUnauthorizedAttempts"
  namespace           = "ECR/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "ECR unauthorized access attempts > 5 in 5 minutes"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}
```

### 10. 보안 체크리스트

#### 배포 전 필수 확인
- [ ] **KMS 암호화**: 모든 리포지토리가 고객 관리형 KMS 키 사용
- [ ] **이미지 스캔**: `scan_on_push = true` 활성화
- [ ] **IAM 권한**: 최소 권한 원칙 적용 (불필요한 `ecr:*` 제거)
- [ ] **리포지토리 정책**: 필요한 계정/서비스만 접근 허용
- [ ] **라이프사이클 정책**: 자동 이미지 정리 정책 설정
- [ ] **이미지 불변성**: `image_tag_mutability = "IMMUTABLE"` (프로덕션)

#### 운영 중 주기적 점검
- [ ] **취약점 스캔**: CRITICAL/HIGH 취약점 즉시 수정 (매주)
- [ ] **CloudTrail 로그**: 비정상적인 Push/Pull 활동 확인 (매주)
- [ ] **IAM Access Analyzer**: 과도한 ECR 권한 검출 (매월)
- [ ] **오래된 이미지**: 라이프사이클 정책 작동 확인 (매월)
- [ ] **크로스 계정 접근**: 리포지토리 정책 검토 (분기별)
- [ ] **KMS 키 회전**: 자동 키 회전 활성화 상태 확인 (분기별)

#### CI/CD 파이프라인 보안
- [ ] **이미지 태그**: 시맨틱 버전 태그 사용 (`v1.0.0`, `v1.0.1`)
- [ ] **취약점 검증**: 배포 전 CRITICAL 취약점 차단
- [ ] **이미지 서명**: Docker Content Trust 또는 AWS Signer 사용
- [ ] **Digest 고정**: 프로덕션 배포 시 SHA256 digest 사용
- [ ] **비밀 정보**: Dockerfile에 secrets/credentials 포함 금지
- [ ] **베이스 이미지**: 신뢰할 수 있는 공식 이미지만 사용

#### 보안 사고 대응
- [ ] **격리 절차**: 취약한 이미지 즉시 태그 제거 또는 삭제
- [ ] **Rollback**: 이전 안전한 이미지로 즉시 롤백
- [ ] **통지**: 보안팀 및 관련 팀에 즉시 알림
- [ ] **조사**: CloudTrail 로그 분석 및 영향 범위 파악

---

## 리소스 태그

모든 리소스는 다음 필수 태그를 포함합니다:

```hcl
tags = merge(
  local.required_tags,
  {
    Name      = "ecr-${local.repository_name}"
    Component = "container-registry"
  }
)
```

**필수 태그** (거버넌스 요구사항):
- `Owner`: 리소스 소유자 (이메일)
- `CostCenter`: 비용 센터
- `Environment`: 환경 (dev, staging, prod)
- `Lifecycle`: 라이프사이클 단계
- `DataClass`: 데이터 분류 수준
- `Service`: 서비스 이름

---

## Troubleshooting

### 1. Docker 이미지 푸시 실패

**증상**: `denied: User: ... is not authorized to perform: ecr:PutImage`

**확인 방법**:
```bash
# ECR 리포지토리 존재 확인
aws ecr describe-repositories \
  --repository-names fileflow \
  --region ap-northeast-2

# 현재 Docker 로그인 상태 확인
cat ~/.docker/config.json
```

**해결 방법**:

1. **ECR 로그인 다시 수행** (12시간 유효):
   ```bash
   aws ecr get-login-password --region ap-northeast-2 | \
     docker login --username AWS --password-stdin \
     646886795421.dkr.ecr.ap-northeast-2.amazonaws.com
   ```

2. **IAM 권한 확인**:
   필요한 권한:
   - `ecr:GetAuthorizationToken`
   - `ecr:BatchCheckLayerAvailability`
   - `ecr:InitiateLayerUpload`
   - `ecr:UploadLayerPart`
   - `ecr:CompleteLayerUpload`
   - `ecr:PutImage`

3. **네트워크 연결 확인**:
   ```bash
   # ECR 엔드포인트 연결 테스트
   telnet 646886795421.dkr.ecr.ap-northeast-2.amazonaws.com 443
   ```

4. **이미지 태그 형식 확인**:
   ```bash
   # 올바른 태그 형식
   docker tag myapp:latest 646886795421.dkr.ecr.ap-northeast-2.amazonaws.com/fileflow:latest
   docker push 646886795421.dkr.ecr.ap-northeast-2.amazonaws.com/fileflow:latest
   ```

### 2. ECS Task에서 이미지 풀링 실패

**증상**: `CannotPullContainerError: Error response from daemon`

**확인 방법**:
```bash
# ECS Task 실패 이유 확인
aws ecs describe-tasks \
  --cluster <cluster-name> \
  --tasks <task-id> \
  --region ap-northeast-2 \
  --query 'tasks[0].stoppedReason'

# Task Execution Role 확인
aws iam get-role \
  --role-name <task-execution-role> \
  --query 'Role.AssumeRolePolicyDocument'
```

**해결 방법**:

1. **Task Execution Role에 ECR 권한 추가**:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "ecr:GetAuthorizationToken",
       "ecr:BatchCheckLayerAvailability",
       "ecr:GetDownloadUrlForLayer",
       "ecr:BatchGetImage"
     ],
     "Resource": "*"
   }
   ```

2. **KMS 키 복호화 권한 추가**:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "kms:Decrypt"
     ],
     "Resource": "arn:aws:kms:ap-northeast-2:646886795421:key/*"
   }
   ```

3. **VPC 엔드포인트 확인** (Private subnet 사용 시):
   ```bash
   # ECR VPC 엔드포인트 확인 (API 및 DKR 모두 필요)
   aws ec2 describe-vpc-endpoints \
     --filters "Name=service-name,Values=com.amazonaws.ap-northeast-2.ecr.api" \
     --region ap-northeast-2

   aws ec2 describe-vpc-endpoints \
     --filters "Name=service-name,Values=com.amazonaws.ap-northeast-2.ecr.dkr" \
     --region ap-northeast-2

   # S3 Gateway 엔드포인트 (이미지 레이어 저장)
   aws ec2 describe-vpc-endpoints \
     --filters "Name=service-name,Values=com.amazonaws.ap-northeast-2.s3" \
     --region ap-northeast-2
   ```

4. **이미지 존재 여부 확인**:
   ```bash
   # 해당 태그의 이미지가 실제로 존재하는지 확인
   aws ecr describe-images \
     --repository-name fileflow \
     --image-ids imageTag=latest \
     --region ap-northeast-2
   ```

### 3. KMS 암호화 키 접근 권한 문제

**증상**: `AccessDeniedException: User is not authorized to perform: kms:Decrypt`

**확인 방법**:
```bash
# KMS 키 정보 확인
aws kms describe-key \
  --key-id alias/ecr-fileflow \
  --region ap-northeast-2

# KMS 키 정책 확인
aws kms get-key-policy \
  --key-id alias/ecr-fileflow \
  --policy-name default \
  --region ap-northeast-2
```

**해결 방법**:

1. **ECS Task Execution Role에 KMS 복호화 권한 추가**:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "kms:Decrypt",
       "kms:DescribeKey"
     ],
     "Resource": "arn:aws:kms:ap-northeast-2:646886795421:key/<key-id>"
   }
   ```

2. **KMS 키 정책에 서비스 권한 확인**:
   - ECR 서비스가 KMS 키를 사용할 수 있는지 확인
   - ECS 서비스가 KMS 키를 복호화할 수 있는지 확인

### 4. 이미지 스캔 실패 또는 누락

**증상**: 이미지 푸시 후 스캔이 실행되지 않거나 실패함

**확인 방법**:
```bash
# 스캔 상태 확인
aws ecr describe-image-scan-findings \
  --repository-name fileflow \
  --image-id imageTag=latest \
  --region ap-northeast-2

# 스캔 이력 확인
aws ecr describe-images \
  --repository-name fileflow \
  --image-ids imageTag=latest \
  --region ap-northeast-2 \
  --query 'imageDetails[0].imageScanStatus'
```

**해결 방법**:

1. **수동으로 스캔 시작**:
   ```bash
   aws ecr start-image-scan \
     --repository-name fileflow \
     --image-id imageTag=latest \
     --region ap-northeast-2
   ```

2. **Scan on Push 설정 확인**:
   ```bash
   aws ecr put-image-scanning-configuration \
     --repository-name fileflow \
     --image-scanning-configuration scanOnPush=true \
     --region ap-northeast-2
   ```

3. **스캔 제한 확인**:
   - ECR은 이미지당 하루 1회만 스캔 가능
   - 24시간 후 다시 시도하거나 새 이미지 태그 사용

### 5. 라이프사이클 정책이 작동하지 않음

**증상**: 오래된 이미지가 자동 삭제되지 않음

**확인 방법**:
```bash
# 현재 라이프사이클 정책 확인
aws ecr get-lifecycle-policy \
  --repository-name fileflow \
  --region ap-northeast-2

# 이미지 개수 확인
aws ecr list-images \
  --repository-name fileflow \
  --region ap-northeast-2 \
  --query 'length(imageIds)'
```

**해결 방법**:

1. **라이프사이클 정책 테스트**:
   ```bash
   # Dry run으로 정책 테스트 (실제 삭제 안 함)
   aws ecr start-lifecycle-policy-preview \
     --repository-name fileflow \
     --region ap-northeast-2
   ```

2. **정책 재적용**:
   ```bash
   # Terraform으로 정책 재설정
   terraform apply -target=aws_ecr_lifecycle_policy.fileflow
   ```

3. **이미지 태그 확인**:
   - Untagged 이미지는 즉시 정리됨
   - Tagged 이미지는 개수 기준(imageCountMoreThan: 10)으로 관리

### 6. 디스크 용량 부족 (빌드 환경)

**증상**: `no space left on device` 오류 발생

**확인 방법**:
```bash
# Docker 디스크 사용량 확인
docker system df

# 미사용 리소스 상세 확인
docker system df -v
```

**해결 방법**:
```bash
# 빌드 캐시 정리
docker builder prune -f

# 미사용 이미지 정리
docker image prune -a -f

# 전체 시스템 정리 (주의!)
docker system prune -a -f --volumes
```

### 7. 일반적인 체크리스트

ECR 배포 및 사용 시 확인 사항:

- [ ] ECR 리포지토리 정상 생성됨
- [ ] KMS 암호화 활성화됨 (`alias/ecr-fileflow`)
- [ ] Scan on Push 활성화됨
- [ ] 라이프사이클 정책 적용됨 (최근 10개 버전 유지)
- [ ] SSM Parameter Store에 리포지토리 URL 저장됨
- [ ] Docker 로그인 성공
- [ ] 이미지 푸시 성공
- [ ] 이미지 스캔 완료 (취약점 확인)
- [ ] ECS Task에서 이미지 풀링 성공
- [ ] Task Execution Role IAM 권한 올바르게 설정됨

---

## Variables

다음은 FileFlow ECR 리포지토리 구성에 사용되는 입력 변수입니다.

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| aws_region | AWS region for ECR repository | string | `ap-northeast-2` | No |
| environment | Environment name (dev, staging, prod) | string | `prod` | No |
| owner | Owner of the resources | string | `platform-team@ryuqqq.com` | No |
| cost_center | Cost center for billing | string | `engineering` | No |
| lifecycle_stage | Lifecycle stage of the resources | string | `production` | No |
| data_class | Data classification level | string | `confidential` | No |
| image_tag_mutability | Image tag mutability setting (MUTABLE or IMMUTABLE) | string | `MUTABLE` | No |
| scan_on_push | Enable image scanning on push | bool | `true` | No |
| lifecycle_policy_max_image_count | Maximum number of images to keep | number | `30` | No |

---

## Outputs

다음은 FileFlow ECR 리포지토리에서 출력되는 값들입니다.

| Name | Description |
|------|-------------|
| repository_url | The URL of the ECR repository |
| repository_arn | The ARN of the ECR repository |
| repository_name | The name of the ECR repository |
| registry_id | The registry ID where the repository was created |

**SSM Parameter Store 참조**:
- `/shared/ecr/fileflow-repository-url` - FileFlow ECR repository URL (크로스 스택 참조용)

---

## 관련 문서

### 내부 문서
- [Infrastructure Governance](../../docs/governance/infrastructure_governance.md) - 태그 표준, KMS 전략
- [Tagging Standards](../../docs/governance/TAGGING_STANDARDS.md) - 필수 태그 요구사항
- [KMS Strategy](../../docs/guides/kms-strategy.md) - KMS 키 관리 전략

### AWS 공식 문서
- [Amazon ECR User Guide](https://docs.aws.amazon.com/ecr/)
- [ECR Encryption at Rest](https://docs.aws.amazon.com/AmazonECR/latest/userguide/encryption-at-rest.html)
- [ECR Image Scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)
- [ECR Lifecycle Policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html)

---

## 다음 단계

### 현재 구성된 리소스
- ✅ FileFlow ECR 리포지토리
- ✅ KMS 암호화
- ✅ 이미지 스캔
- ✅ 라이프사이클 정책
- ✅ SSM Parameter 크로스 스택 참조

### 추가 계획
- [ ] 추가 서비스용 ECR 리포지토리 생성 (필요 시)
- [ ] 이미지 스캔 결과 CloudWatch 알람 연동
- [ ] 리포지토리 메트릭 모니터링 대시보드

---

## 관련 Epic 및 Task

- **Epic**: 관련 Epic 정보 추가 필요
- **Jira**: 관련 Jira Task 추가 필요

---

**Last Updated**: 2025-01-22
**Maintained By**: Platform Team
