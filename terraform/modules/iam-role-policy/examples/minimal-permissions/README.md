# Minimal Permissions Example

이 예시는 최소 권한 원칙(Least Privilege Principle)을 적용한 IAM Role을 보여줍니다.

## 최소 권한 원칙이란?

사용자나 애플리케이션에게 작업 수행에 필요한 최소한의 권한만 부여하는 보안 원칙입니다.

## 포함된 예시

### 1. Minimal Lambda Role

Lambda 함수가 동작하는데 필요한 최소한의 권한만 부여:

- ✅ CloudWatch Logs 작성 (필수)
- ✅ 특정 Secret 읽기 (읽기만)
- ✅ 특정 S3 객체 읽기 (1개 파일만)
- ✅ KMS 복호화 (특정 키만)
- ❌ 쓰기/삭제 권한 없음
- ❌ 로그 그룹 생성 권한 없음

### 2. Read-Only Data Processor Role

데이터 처리 워커에 읽기 전용 권한만 부여:

- ✅ RDS 읽기 (IAM 인증)
- ✅ S3 읽기 (특정 경로)
- ✅ CloudWatch Logs 작성
- ❌ RDS 쓰기 권한 없음
- ❌ S3 쓰기 권한 없음

## 사용 방법

```bash
# Initialize and apply
terraform init
terraform plan
terraform apply

# Get the role ARNs
terraform output lambda_role_arn
terraform output data_processor_role_arn
```

## 최소 권한 체크리스트

### ✅ 권장 사항

1. **구체적인 리소스 지정**
   ```hcl
   # ✅ 좋음
   s3_object_arns = ["arn:aws:s3:::my-bucket/specific/path/*"]

   # ❌ 나쁨
   s3_object_arns = ["arn:aws:s3:::*/*"]
   ```

2. **읽기/쓰기 권한 분리**
   ```hcl
   # ✅ 좋음 - 읽기만 필요한 경우
   s3_allow_write = false
   secrets_manager_allow_update = false
   ```

3. **권한 플래그 명시적 설정**
   ```hcl
   # ✅ 좋음 - 필요한 권한만 true
   secrets_manager_allow_create = false
   secrets_manager_allow_update = false
   secrets_manager_allow_delete = false
   ```

4. **리소스별 역할 분리**
   - 데이터 읽기 역할 ≠ 데이터 쓰기 역할
   - 개발 환경 역할 ≠ 프로덕션 역할

### ❌ 피해야 할 사항

1. **와일드카드 남용**
   ```hcl
   # ❌ 나쁨
   s3_bucket_arns = ["arn:aws:s3:::*"]
   ```

2. **불필요한 쓰기 권한**
   ```hcl
   # ❌ 나쁨 - 읽기만 필요한데 쓰기 권한 부여
   s3_allow_write = true
   secrets_manager_allow_delete = true
   ```

3. **과도한 범위**
   ```hcl
   # ❌ 나쁨
   cloudwatch_log_group_arns = ["arn:aws:logs:*:*:log-group:*"]
   ```

## 권한 검증 방법

### 1. IAM Policy Simulator 사용

AWS IAM Policy Simulator로 권한 테스트:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/example-minimal-lambda-role \
  --action-names s3:PutObject \
  --resource-arns arn:aws:s3:::example-config-bucket/lambda/config.json
```

### 2. 런타임 테스트

실제 환경에서 필요한 작업만 수행되는지 확인:

```python
# Lambda 함수에서 테스트
import boto3

# ✅ 성공해야 함
s3 = boto3.client('s3')
s3.get_object(Bucket='example-config-bucket', Key='lambda/config.json')

# ❌ 실패해야 함 (권한 없음)
try:
    s3.put_object(Bucket='example-config-bucket', Key='test.txt', Body='test')
except Exception as e:
    print(f"Expected error: {e}")
```

### 3. CloudTrail 로그 분석

권한 사용 패턴 분석:

```bash
# 실제 사용된 API 호출 확인
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=example-minimal-lambda-role \
  --max-results 50
```

## 정기 권한 검토

1. **월간 권한 감사**
   - CloudTrail 로그로 실제 사용된 권한 분석
   - 사용하지 않는 권한 제거

2. **분기별 보안 검토**
   - AWS Access Advisor로 서비스 접근 패턴 확인
   - 과도한 권한 식별 및 축소

3. **연간 아키텍처 재검토**
   - 역할 구조 전반 재평가
   - 최신 AWS 보안 best practices 적용

## 보안 알림 설정

CloudWatch Alarms로 비정상 권한 사용 감지:

```hcl
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "UnauthorizedAPICalls"
  log_group_name = "/aws/cloudtrail/my-trail"

  pattern = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedAPICallsCount"
    namespace = "CloudTrail"
    value     = "1"
  }
}
```

## 추가 리소스

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Principle of Least Privilege](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#grant-least-privilege)
- [IAM Access Analyzer](https://aws.amazon.com/iam/features/analyze-access/)
