# Infrastructure Shared Resources Command

환경 간 공유되는 인프라 리소스를 관리합니다.

## 사용법

```
/if:shared <action> [resource] [options]
```

## 액션

```bash
/if:shared list              # 공유 리소스 목록
/if:shared create <resource> # 새 공유 리소스 생성
/if:shared analyze           # 공유 리소스 의존성 분석
/if:shared sync              # 환경 간 동기화 상태 확인
```

## 공유 리소스 구조

```
terraform/shared/
├── kms/                  # KMS 키
├── network/              # 네트워크 (VPC, Subnets)
├── iam/                  # IAM 공통 역할/정책
├── route53/              # Route53 호스팅 영역
├── acm/                  # ACM 인증서
└── ecr/                  # ECR 레포지토리
```

## 공유 리소스 패턴

### Cross-Stack Reference

```hcl
# Output → SSM Parameter Store → Input
# (직접 cross-stack 의존성 금지)

# 1. 출력 측 (terraform/shared/kms)
resource "aws_ssm_parameter" "kms_key_arn" {
  name  = "/infrastructure/kms/logs/arn"
  type  = "String"
  value = aws_kms_key.logs.arn
}

# 2. 입력 측 (terraform/environments/prod/logs)
data "aws_ssm_parameter" "kms_key_arn" {
  name = "/infrastructure/kms/logs/arn"
}
```

### State 분리

| 레벨 | 경로 | 용도 |
|------|------|------|
| shared | terraform/shared/* | 전역 공유 리소스 |
| prod | terraform/environments/prod/* | 프로덕션 환경 |
| stage | terraform/environments/stage/* | 스테이징 환경 |

### Backend 설정

```hcl
terraform {
  backend "s3" {
    bucket         = "ryuqqq-${var.env}-tfstate"
    key            = "${var.stack}/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
    kms_key_id     = "alias/terraform-state"
  }
}
```

## 공유 리소스 목록

### KMS 키

| 키 | 용도 | 환경 |
|----|------|------|
| terraform-state | State 암호화 | 전역 |
| logs | CloudWatch Logs | 전역 |
| rds | RDS 암호화 | 환경별 |
| s3 | S3 버킷 암호화 | 환경별 |
| ecr | ECR 이미지 암호화 | 전역 |

### 네트워크

| 리소스 | CIDR | 환경 |
|--------|------|------|
| VPC | 10.0.0.0/16 | prod |
| VPC | 10.1.0.0/16 | stage |
| Public Subnet | /20 | Multi-AZ |
| Private Subnet | /19 | Multi-AZ |
| Data Subnet | /20 | Multi-AZ |

### VPC Endpoints

| 엔드포인트 | 타입 | 비용 최적화 |
|-----------|------|-------------|
| S3 | Gateway | ✅ 무료 |
| DynamoDB | Gateway | ✅ 무료 |
| ECR | Interface | 💰 유료 |
| Secrets Manager | Interface | 💰 유료 |

## 의존성 분석

```bash
# 공유 리소스 의존성 그래프
/if:shared analyze --graph

# 특정 리소스 사용처 확인
/if:shared analyze kms/logs

# 환경별 의존성 확인
/if:shared analyze --env prod
```

출력 예시:

```
📊 Shared Resource Dependencies
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔑 KMS: kms/logs
├── prod/cloudwatch-log-group (5 references)
├── prod/ecs-service (3 references)
└── stage/cloudwatch-log-group (2 references)

🌐 Network: shared/vpc
├── prod/alb (1 reference)
├── prod/ecs-service (4 references)
├── prod/rds (1 reference)
└── stage/* (8 references)
```

## 동기화 확인

```bash
# 환경 간 동기화 상태
/if:shared sync

# 불일치 항목 확인
/if:shared sync --diff
```

## 예제

```bash
# 공유 리소스 목록
/if:shared list

# 새 KMS 키 생성
/if:shared create kms/secrets

# 의존성 분석
/if:shared analyze

# 동기화 상태 확인
/if:shared sync
```

## 베스트 프랙티스

1. **명확한 경계**: shared vs environment 구분 명확히
2. **SSM Parameter Store**: cross-stack 참조 시 사용
3. **State 격리**: 환경별 state 파일 분리
4. **문서화**: 공유 리소스 용도 명시
5. **변경 영향도**: 변경 전 의존성 분석 필수

## 관련 커맨드

- `/if:module` - 모듈 생성/관리
- `/if:validate` - 거버넌스 검증
- `/if:atlantis` - Atlantis 작업
