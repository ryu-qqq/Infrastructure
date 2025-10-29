# Terraform Templates

## 개요 (Overview)

인프라 코드 자동 생성을 위한 Jinja2 템플릿 모음입니다. 각 템플릿은 특정 AWS 서비스나 패턴에 대한 표준화된 Terraform 구성을 생성합니다.

## 사용 방법 (Usage)

### 템플릿 구조

각 서비스 템플릿 디렉토리는 다음 파일들을 포함합니다:

```
{service-name}/
├── metadata.json      # 템플릿 메타데이터 및 변수 정의
├── README.md.j2       # 생성될 README 템플릿
├── main.tf.j2         # 메인 리소스 정의 템플릿
├── variables.tf.j2    # 변수 정의 템플릿
├── outputs.tf.j2      # 출력 값 템플릿
├── provider.tf.j2     # Provider 설정 템플릿
├── data.tf.j2         # Data source 템플릿
└── locals.tf.j2       # Local 값 템플릿
```

### 사용 예시

```bash
# 인프라 위자드 스크립트를 통한 사용
./scripts/infra-wizard.py

# 또는 직접 템플릿 렌더링
jinja2 templates/ecs-service/main.tf.j2 \
  -D service_name=api-server \
  -D environment=prod \
  > terraform/services/api-server/main.tf
```

## 📦 사용 가능한 템플릿

| 템플릿 이름 | 설명 | 주요 리소스 |
|-------------|------|-------------|
| `ecs-service` | ECS Fargate 서비스 | ECS Service, Task Definition, ALB |
| `lambda-function` | Lambda 함수 | Lambda Function, IAM Role, CloudWatch Logs |
| `rds-mysql` | RDS MySQL 데이터베이스 | RDS Instance, Subnet Group, Security Group |
| `rds-postgres` | RDS PostgreSQL 데이터베이스 | RDS Instance, Subnet Group, Security Group |
| `elasticache-redis` | ElastiCache Redis 클러스터 | Redis Cluster, Subnet Group, Security Group |
| `s3-bucket` | S3 버킷 (암호화, 버전관리) | S3 Bucket, Bucket Policy, Lifecycle Rules |
| `sqs-queue` | SQS 큐 | SQS Queue, Dead Letter Queue |
| `firehose-s3-logs` | Kinesis Firehose (로그 수집) | Firehose, S3, IAM Role |

## Variables

템플릿 시스템은 중앙화된 variables.tf 파일이 없습니다. 각 템플릿의 `metadata.json` 파일에서 필요한 변수들이 정의되어 있습니다.

### 공통 변수
대부분의 템플릿은 다음 공통 변수들을 사용합니다:
- `service_name`: 서비스 이름
- `environment`: 환경 (dev, staging, prod)
- `aws_region`: AWS 리전
- `team`: 담당 팀
- `owner`: 소유자 이메일

자세한 변수 목록은 각 템플릿의 `metadata.json` 파일을 참조하세요.

## Outputs

템플릿으로 생성된 Terraform 코드는 각각 고유한 outputs.tf 파일을 생성합니다.

일반적으로 다음과 같은 출력이 포함됩니다:
- 리소스 ID 및 ARN
- 엔드포인트 URL
- 보안 그룹 ID
- IAM Role ARN

자세한 출력 내용은 각 템플릿의 `outputs.tf.j2` 파일을 참조하세요.

## 템플릿 추가하기

새로운 서비스 템플릿을 추가하려면:

1. 새 디렉토리 생성: `templates/{service-name}/`
2. `metadata.json` 파일 작성 (변수 정의 및 설명)
3. 필요한 `.j2` 템플릿 파일들 작성
4. `registry.json`에 템플릿 등록

예시는 기존 템플릿들을 참조하세요.

## 거버넌스 준수

모든 템플릿은 다음 거버넌스 요구사항을 준수합니다:
- ✅ 필수 태그 (`Owner`, `CostCenter`, `Environment`, `Service` 등)
- ✅ KMS 암호화 (해당되는 경우)
- ✅ 표준 네이밍 규칙 (kebab-case)
- ✅ 보안 그룹 최소 권한 원칙

## 관련 문서

- [Infrastructure Wizard Guide](../../scripts/README.md) - 인프라 위자드 사용법
- [Terraform Best Practices](../../docs/guides/terraform-best-practices.md)
- [Infrastructure Governance](../../docs/governance/infrastructure_governance.md)

---

**Last Updated**: 2025-01-29
**Maintained By**: Platform Team
