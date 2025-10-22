# ECR Basic Example

이 예제는 Amazon Elastic Container Registry (ECR)의 기본 리포지토리를 생성하는 방법을 보여줍니다.

## 개요

이 예제에서 배포되는 리소스:

- **KMS Key**: ECR 이미지 암호화용 Customer-Managed Key
- **ECR Repository**: Docker 이미지 저장소
- **Lifecycle Policy**: 오래된 이미지 자동 정리
- **Repository Policy** (선택): 크로스 계정 이미지 Pull 권한

## 기능

- ✅ **KMS 암호화**: Customer-Managed Key를 사용한 at-rest 암호화
- ✅ **이미지 스캔**: Push 시 자동 보안 취약점 스캔
- ✅ **라이프사이클 정책**: 최근 N개 이미지만 보관
- ✅ **태그 변경 방지**: IMMUTABLE 설정 지원
- ✅ **크로스 계정 접근**: 다른 AWS 계정에서 이미지 Pull 허용

## 사용 방법

### 1. Variables 설정

`terraform.tfvars` 파일 생성:

```hcl
repository_name      = "my-application"
environment          = "dev"
aws_region           = "ap-northeast-2"

# 이미지 관리
image_tag_mutability = "MUTABLE"  # 또는 "IMMUTABLE"
scan_on_push         = true
max_image_count      = 30

# 크로스 계정 접근 (선택)
allow_cross_account_pull = false
# allowed_account_ids    = ["123456789012"]

# Required Tags
owner              = "platform-team"
cost_center        = "engineering"
resource_lifecycle = "permanent"
data_class         = "confidential"
service            = "container-registry"
```

### 2. Terraform 실행

```bash
# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply
```

### 3. 이미지 Push

배포 완료 후 Docker 이미지를 Push:

```bash
# ECR 로그인 (토큰은 12시간 유효)
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 빌드
docker build -t my-application:latest .

# 이미지 태그
docker tag my-application:latest \
  <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/my-application:latest

# 이미지 Push
docker push <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/my-application:latest
```

## 주요 구성 설정

### Image Tag Mutability

- **MUTABLE**: 같은 태그로 여러 번 Push 가능 (개발 환경 권장)
- **IMMUTABLE**: 태그 고정, 한 번 Push 후 변경 불가 (프로덕션 권장)

### 이미지 스캔

`scan_on_push = true`로 설정하면:
- 이미지 Push 시 자동으로 CVE 취약점 스캔
- 스캔 결과는 ECR 콘솔 또는 AWS CLI로 확인 가능

```bash
# 스캔 결과 확인
aws ecr describe-image-scan-findings \
  --repository-name my-application \
  --image-id imageTag=latest \
  --region ap-northeast-2
```

### 라이프사이클 정책

`max_image_count = 30`으로 설정하면:
- 최근 30개 이미지만 보관
- 오래된 이미지 자동 삭제
- 스토리지 비용 절감

## 비용 예상

ECR 비용 구조 (서울 리전 기준):

| 항목 | 비용 | 설명 |
|------|------|------|
| 스토리지 | $0.10/GB/월 | 압축된 이미지 크기 기준 |
| 데이터 전송 (IN) | 무료 | 인터넷 또는 같은 리전에서 Push |
| 데이터 전송 (OUT) | $0.126/GB | 인터넷으로 Pull |
| KMS 키 | $1/월 | Customer-Managed Key |

**예상 월 비용 (100GB 스토리지 기준)**:
- 스토리지: $10
- KMS 키: $1
- 데이터 전송: 트래픽에 따라 변동
- **총 예상**: ~$11 + 데이터 전송 비용

## 보안 고려사항

### 1. KMS 암호화

- Customer-Managed Key를 사용하여 at-rest 암호화
- 자동 키 회전 활성화 (`enable_key_rotation = true`)
- 30일 삭제 대기 기간 설정

### 2. 이미지 스캔

- Push 시 자동 스캔으로 취약점 조기 발견
- 스캔 결과 모니터링 필수
- HIGH/CRITICAL 취약점 발견 시 즉시 대응

### 3. 접근 제어

- IAM 정책으로 리포지토리 접근 제어
- 최소 권한 원칙 적용
- 크로스 계정 접근은 신중히 검토

### 4. 이미지 태그 전략

프로덕션 환경:
- IMMUTABLE 태그 사용 권장
- Semantic Versioning 적용 (v1.2.3)
- Git SHA 태그 병행 사용

개발 환경:
- MUTABLE 태그 허용
- `latest`, `dev`, `staging` 등 환경별 태그

## 이미지 관리 Best Practices

### 1. 태그 전략

```bash
# 버전 태그
docker tag app:latest <ecr-url>/app:v1.2.3

# Git SHA 태그
docker tag app:latest <ecr-url>/app:${GIT_SHA}

# 환경 태그
docker tag app:latest <ecr-url>/app:prod-latest
```

### 2. 라이프사이클 정책

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 30 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

### 3. CI/CD 통합

```yaml
# GitHub Actions 예시
- name: Build and Push to ECR
  run: |
    aws ecr get-login-password --region ap-northeast-2 | \
      docker login --username AWS --password-stdin $ECR_REGISTRY

    docker build -t $ECR_REGISTRY/app:${{ github.sha }} .
    docker push $ECR_REGISTRY/app:${{ github.sha }}

    docker tag $ECR_REGISTRY/app:${{ github.sha }} $ECR_REGISTRY/app:latest
    docker push $ECR_REGISTRY/app:latest
```

## Outputs

배포 후 다음 정보를 확인할 수 있습니다:

```bash
# Repository URL
terraform output repository_url

# Repository ARN
terraform output repository_arn

# KMS Key ARN
terraform output kms_key_arn
```

## 크로스 계정 접근 설정

다른 AWS 계정에서 이미지를 Pull하려면:

### 1. Repository Policy 설정

`terraform.tfvars`:

```hcl
allow_cross_account_pull = true
allowed_account_ids      = ["123456789012", "234567890123"]
```

### 2. 대상 계정 IAM 정책

대상 계정의 IAM Role/User에 다음 권한 부여:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ],
      "Resource": "arn:aws:ecr:ap-northeast-2:<source-account>:repository/my-application"
    }
  ]
}
```

## 정리 (Clean Up)

리소스 삭제:

```bash
# 리포지토리의 모든 이미지 삭제 (필수)
aws ecr batch-delete-image \
  --repository-name my-application \
  --image-ids "$(aws ecr list-images --repository-name my-application --query 'imageIds[*]' --output json)" \
  --region ap-northeast-2

# Terraform으로 리소스 삭제
terraform destroy
```

**주의사항**:
- ECR 리포지토리에 이미지가 있으면 삭제가 실패합니다
- 먼저 모든 이미지를 삭제한 후 `terraform destroy`를 실행하세요

## 참고 자료

- [Amazon ECR 공식 문서](https://docs.aws.amazon.com/AmazonECR/latest/userguide/)
- [ECR 이미지 스캔](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)
- [ECR 라이프사이클 정책](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html)
- [ECR 전체 패키지 문서](../../README.md)

## 문의

- **Task**: ECR 리포지토리 관리
- **문의 채널**: Slack #infrastructure
