# ECR Repository - FileFlow

## 개요 (Overview)

FileFlow 서비스용 Amazon ECR(Elastic Container Registry) 프라이빗 리포지토리입니다. Docker 이미지 저장, 버전 관리, 취약점 스캔 기능을 제공합니다.

## 사용 방법 (Usage)

### 1. 인프라 배포

```bash
cd terraform/ecr/fileflow

# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply
```

### 2. Docker 이미지 빌드 및 푸시

```bash
# AWS ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  $(terraform output -raw repository_url | cut -d'/' -f1)

# 이미지 빌드
docker build -t fileflow:latest .

# 이미지 태깅
docker tag fileflow:latest $(terraform output -raw repository_url):latest
docker tag fileflow:latest $(terraform output -raw repository_url):v1.0.0

# 이미지 푸시
docker push $(terraform output -raw repository_url):latest
docker push $(terraform output -raw repository_url):v1.0.0
```

### 3. ECS에서 이미지 사용

```hcl
resource "aws_ecs_task_definition" "fileflow" {
  container_definitions = jsonencode([{
    name  = "fileflow"
    image = data.aws_ssm_parameter.fileflow_ecr_url.value
    # ...
  }])
}

data "aws_ssm_parameter" "fileflow_ecr_url" {
  name = "/shared/ecr/fileflow-repository-url"
}
```

## 주요 기능

### 보안 기능
- ✅ **KMS 암호화**: 이미지 레이어 암호화
- ✅ **이미지 스캔**: 푸시 시 자동 취약점 스캔
- ✅ **IAM 접근 제어**: 최소 권한 원칙 적용
- ✅ **프라이빗 리포지토리**: VPC 내부에서만 접근 가능

### 라이프사이클 관리
- 최근 30개 이미지 유지
- 오래된 이미지 자동 삭제
- 태그가 없는 이미지 7일 후 삭제

## Variables

| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `aws_region` | AWS 리전 | `string` | `ap-northeast-2` | No |
| `environment` | 환경 이름 (dev, staging, prod) | `string` | `prod` | No |
| `owner` | 리소스 소유자 | `string` | `fbtkdals2@naver.com` | No |
| `cost_center` | 비용 센터 | `string` | `engineering` | No |
| `image_tag_mutability` | 이미지 태그 변경 가능 여부 (MUTABLE/IMMUTABLE) | `string` | `MUTABLE` | No |
| `scan_on_push` | 푸시 시 이미지 스캔 활성화 | `bool` | `true` | No |
| `lifecycle_policy_max_image_count` | 유지할 최대 이미지 개수 | `number` | `30` | No |

자세한 내용은 [variables.tf](./variables.tf) 파일을 참조하세요.

## Outputs

| 출력 이름 | 설명 |
|-----------|------|
| `repository_url` | ECR 리포지토리 URL (예: `123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/fileflow`) |
| `repository_arn` | ECR 리포지토리 ARN |
| `repository_name` | ECR 리포지토리 이름 (`fileflow`) |
| `registry_id` | ECR 레지스트리 ID (AWS 계정 ID) |

### SSM Parameter Export
- `/shared/ecr/fileflow-repository-url`: 다른 스택에서 참조 가능한 리포지토리 URL

자세한 내용은 [outputs.tf](./outputs.tf) 파일을 참조하세요.

## 이미지 스캔

### 스캔 결과 확인

```bash
# 최신 스캔 결과 조회
aws ecr describe-image-scan-findings \
  --repository-name fileflow \
  --image-id imageTag=latest \
  --region ap-northeast-2

# 취약점 요약
aws ecr describe-image-scan-findings \
  --repository-name fileflow \
  --image-id imageTag=latest \
  --query 'imageScanFindings.findingSeverityCounts' \
  --region ap-northeast-2
```

### 취약점 대응

| 심각도 | 대응 방침 |
|--------|-----------|
| CRITICAL | 즉시 패치 또는 이미지 재빌드 필요 |
| HIGH | 24시간 내 조치 |
| MEDIUM | 주간 스프린트 내 조치 |
| LOW | 다음 메이저 업데이트 시 조치 |

## 비용 최적화

### 현재 설정
- 최근 30개 이미지만 유지
- 태그 없는 이미지 7일 후 자동 삭제
- 월 예상 스토리지: ~10GB = $1/월

### 추가 절감 방안
- 이미지 압축 최적화 (멀티 스테이지 빌드)
- 불필요한 레이어 제거
- 베이스 이미지 경량화 (alpine 사용)

## 트러블슈팅

### 푸시 권한 오류
```bash
# IAM 권한 확인
aws ecr get-authorization-token --region ap-northeast-2

# IAM 정책 확인
aws iam list-attached-role-policies --role-name github-actions-role
```

### 이미지 스캔 실패
```bash
# 스캔 상태 확인
aws ecr describe-images \
  --repository-name fileflow \
  --query 'imageDetails[*].[imageTags[0],imageScanStatus.status]' \
  --output table
```

## 관련 문서

- [ECR 상위 README](../README.md) - ECR 전체 구조 및 전략
- [Infrastructure Governance](../../../docs/governance/infrastructure_governance.md)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)

---

**Last Updated**: 2025-01-29
**Maintained By**: Platform Team
