# Atlantis IAM AssumeRole 권한 구조

> **TASK 1-2**: IAM AssumeRole 권한 구조 설계
> **Epic**: EPIC 1 - Atlantis 플랫폼 구축

## 📋 개요

Atlantis가 각 환경(dev/stg/prod)의 AWS 리소스를 관리할 수 있도록 IAM AssumeRole 기반 권한 체계를 구축합니다.

### 핵심 원칙

- **최소 권한 원칙**: 각 Role은 Terraform 실행에 필요한 최소 권한만 부여
- **환경 분리**: dev/stg/prod 환경별로 독립적인 Target Role 사용
- **크로스 계정 지원**: AssumeRole 패턴으로 멀티 계정 환경 지원 가능

## 🏗️ 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    Atlantis ECS Task                     │
│                 (atlantis-task-role)                     │
│                                                           │
│  • ECS Task에서 실행되는 Atlantis 서비스                │
│  • sts:AssumeRole 권한 보유                             │
└───────────────────┬─────────────────────────────────────┘
                    │
                    │ AssumeRole
                    │
        ┌───────────┴───────────┬───────────────┐
        │                       │               │
        ▼                       ▼               ▼
┌──────────────┐       ┌──────────────┐  ┌──────────────┐
│  dev 환경     │       │  stg 환경     │  │  prod 환경    │
│ Target Role  │       │ Target Role  │  │ Target Role  │
│              │       │              │  │              │
│ • ECS 관리   │       │ • ECS 관리   │  │ • ECS 관리   │
│ • RDS 관리   │       │ • RDS 관리   │  │ • RDS 관리   │
│ • ALB 관리   │       │ • ALB 관리   │  │ • ALB 관리   │
│ • VPC 관리   │       │ • VPC 관리   │  │ • VPC 관리   │
└──────────────┘       └──────────────┘  └──────────────┘
```

## 📦 생성되는 리소스

### 1. Atlantis Task Role

**이름**: `atlantis-task-role`

**설명**: ECS에서 실행되는 Atlantis 서비스가 사용하는 Role

**권한**:
- `sts:AssumeRole` - Target Roles를 Assume할 수 있는 권한

**Trust Policy**: ECS Tasks 서비스가 이 Role을 Assume 가능

### 2. Target Roles (환경별)

| 환경 | Role 이름 | 설명 |
|------|----------|------|
| dev | `atlantis-target-dev` | dev 환경 리소스 관리 |
| stg | `atlantis-target-stg` | stg 환경 리소스 관리 |
| prod | `atlantis-target-prod` | prod 환경 리소스 관리 |

**Trust Policy**: `atlantis-task-role`만 Assume 가능

### 3. Target Role 권한 정책

모든 Target Role에 동일한 기본 권한 부여 (환경별 커스터마이징 가능):

#### ECS 권한
- Cluster, Service, Task Definition 생성/수정/삭제
- 태그 관리

#### RDS 권한
- DB Instance 생성/수정/삭제
- Subnet Group, Parameter Group 관리
- 태그 관리

#### ALB 권한
- Load Balancer, Target Group 생성/수정/삭제
- Listener 관리
- 태그 관리

#### VPC 권한
- VPC, Subnet, Security Group 관리
- 보안 그룹 규칙 관리
- 태그 관리

#### IAM 권한 (제한적)
- ECS Task Role/Execution Role 관리
- `iam:PassRole` 권한 (ECS 서비스용)

#### CloudWatch Logs 권한
- Log Group 생성/삭제/관리
- Retention 정책 설정

#### Secrets Manager 권한 (읽기 전용)
- Secret 값 읽기
- Secret 메타데이터 조회

## 🚀 사용 방법

### 1. Terraform 초기화 및 배포

```bash
cd terraform/atlantis-iam

# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply
```

### 2. Output 확인

```bash
# 모든 Role ARN 확인
terraform output

# 특정 Role ARN 확인
terraform output atlantis_task_role_arn
terraform output atlantis_target_dev_role_arn
```

### 3. AssumeRole 테스트

```bash
# 테스트 스크립트 실행 (모든 환경 테스트)
./test-assume-role.sh
```

테스트 스크립트는 다음을 검증합니다:
- ✅ 각 Target Role로 AssumeRole 성공 여부
- ✅ Assumed Role의 Identity 확인
- ✅ 기본 권한 테스트 (ECS, RDS, VPC describe)

### 4. Atlantis 설정

Atlantis ECS Task Definition에서 `atlantis-task-role`을 Task Role로 설정:

```hcl
resource "aws_ecs_task_definition" "atlantis" {
  family                   = "atlantis"
  task_role_arn            = "arn:aws:iam::<account-id>:role/atlantis-task-role"
  execution_role_arn       = "arn:aws:iam::<account-id>:role/atlantis-execution-role"
  # ... 기타 설정
}
```

### 5. 서비스 레포에서 AssumeRole 사용

서비스 레포의 Terraform에서 환경별 Target Role을 Assume:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "fileflow/dev/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"

    # dev 환경 Target Role Assume
    role_arn = "arn:aws:iam::<account-id>:role/atlantis-target-dev"
  }
}

provider "aws" {
  region = "ap-northeast-2"

  assume_role {
    role_arn = "arn:aws:iam::<account-id>:role/atlantis-target-dev"
  }
}
```

## 🔒 보안 고려사항

### 1. 최소 권한 원칙
- 각 Target Role은 Terraform 실행에 필요한 최소 권한만 부여
- IAM 권한은 ECS Task Role/Execution Role 생성으로 제한
- Secrets Manager는 읽기 전용

### 2. Trust Policy 제한
- Target Role은 오직 `atlantis-task-role`만 Assume 가능
- 다른 Principal은 접근 불가

### 3. 환경 분리
- dev/stg/prod 각 환경별로 독립적인 Role 사용
- 환경 간 권한 격리

### 4. 추가 권한 요청 프로세스

서비스 레포에서 추가 권한이 필요한 경우:

1. **Issue 생성**: 중앙 인프라 레포에 권한 요청 Issue 작성
2. **리뷰**: 플랫폼 팀 + 보안 팀 검토
3. **승인**: 보안 리뷰 통과 시 권한 추가
4. **적용**: Terraform으로 Target Role 정책 업데이트

## 📊 권한 매트릭스

| 서비스 | 권한 | dev | stg | prod | 비고 |
|--------|------|:---:|:---:|:----:|------|
| ECS | Full | ✅ | ✅ | ✅ | Task 정의 및 Service 관리 |
| RDS | Full | ✅ | ✅ | ✅ | Instance 및 Subnet/PG 관리 |
| ALB | Full | ✅ | ✅ | ✅ | LB, TG, Listener 관리 |
| VPC | Full | ✅ | ✅ | ✅ | VPC, Subnet, SG 관리 |
| IAM | Limited | ✅ | ✅ | ✅ | ECS Role만 생성 가능 |
| CloudWatch Logs | Full | ✅ | ✅ | ✅ | Log Group 관리 |
| Secrets Manager | Read-Only | ✅ | ✅ | ✅ | Secret 읽기만 가능 |

## 🧪 테스트

### 수동 테스트

```bash
# 1. dev 환경 Role Assume
aws sts assume-role \
  --role-arn "arn:aws:iam::<account-id>:role/atlantis-target-dev" \
  --role-session-name "manual-test"

# 2. 자격 증명 설정
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."

# 3. 권한 테스트
aws ecs describe-clusters --region ap-northeast-2
aws rds describe-db-instances --region ap-northeast-2
aws ec2 describe-vpcs --region ap-northeast-2
```

### 자동 테스트

```bash
./test-assume-role.sh
```

## 📝 완료 기준

- ✅ Atlantis Task Role 생성 완료
- ✅ dev/stg/prod Target Role 생성 완료
- ✅ Trust Policy 설정 완료
- ✅ 권한 정책 정의 완료 (최소 권한 원칙 적용)
- ✅ AssumeRole 테스트 성공
- ✅ 문서화 완료

## 🔗 관련 문서

- [AWS IAM AssumeRole 공식 문서](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use.html)
- [Terraform AWS Provider assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#assuming-an-iam-role)
- [Atlantis Server Configuration](https://www.runatlantis.io/docs/server-configuration.html)

## 🚧 향후 개선사항

- [ ] Session Duration 커스터마이징
- [ ] 환경별 권한 차이 설정 (prod는 더 제한적)
- [ ] CloudTrail 로그 분석으로 사용되지 않는 권한 식별
- [ ] Service Control Policy (SCP) 적용 (멀티 계정 환경)
- [ ] IAM Access Analyzer 통합

## 📞 지원

문제 발생 시:
1. Atlantis 로그 확인
2. CloudTrail에서 AssumeRole 이벤트 확인
3. 플랫폼 팀에 문의

---

**작성일**: 2025-10-13
**작성자**: Infrastructure Team
**버전**: 1.0.0
