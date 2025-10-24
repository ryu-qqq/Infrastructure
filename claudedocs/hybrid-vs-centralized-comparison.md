# 하이브리드 vs 중앙 집중형 인프라 관리 비교

## 현재 상태 진단: 중앙 집중형 ✅

### 증거
1. **atlantis.yaml L149-156**: ECR fileflow 프로젝트 등록
2. **terraform/ecr/fileflow/**: ECR 레포지토리를 Infrastructure 레포에서 관리
3. **FileFlow 앱 레포**: 인프라 코드 없음 (예상)

→ **결론**: 이건 중앙 집중형입니다!

---

## 인프라 관리 패턴 비교

### 1. 중앙 집중형 (Centralized) - 현재 구조

```
📦 Infrastructure 레포 (이 레포)
├── terraform/
│   ├── bootstrap/              # Terraform state backend
│   ├── kms/                    # KMS 키
│   ├── network/                # VPC, 서브넷
│   ├── rds/                    # 공유 데이터베이스
│   ├── secrets/                # Secrets Manager
│   ├── monitoring/             # CloudWatch, SNS
│   ├── atlantis/               # Atlantis 서버
│   └── ecr/
│       └── fileflow/           # FileFlow ECR ⭐
└── atlantis.yaml               # 모든 프로젝트 등록

📦 FileFlow 앱 레포
├── app/                        # 애플리케이션 코드
├── docker/                     # Dockerfile
└── .github/workflows/
    └── deploy.yml              # 배포만
```

**특징**:
- ✅ 모든 인프라를 한 곳에서 관리
- ✅ 일관성 보장 (governance, tagging, naming)
- ✅ Atlantis 설정 단순
- ❌ 애플리케이션 팀 자율성 제한
- ❌ Infrastructure 레포가 병목점
- ❌ 앱 배포와 인프라 변경 분리

---

### 2. 완전 하이브리드 (True Hybrid)

```
📦 Infrastructure 레포 (공유 인프라만)
├── terraform/
│   ├── bootstrap/              # State backend
│   ├── kms/                    # 공유 KMS 키
│   ├── network/                # VPC, 서브넷
│   ├── rds/                    # 공유 데이터베이스
│   ├── secrets/                # 공유 시크릿
│   └── monitoring/             # 공유 모니터링
├── atlantis.yaml               # 공유 인프라만
└── outputs-to-ssm/             # SSM Parameter Store로 export
    └── main.tf                 # VPC ID, 서브넷 등 export

📦 FileFlow 앱 레포 (애플리케이션 인프라 포함)
├── app/                        # 애플리케이션 코드
├── docker/                     # Dockerfile
├── terraform/                  # ⭐ 애플리케이션 인프라
│   ├── backend.tf              # State backend 설정
│   ├── data.tf                 # 공유 인프라 참조
│   ├── ecr.tf                  # FileFlow ECR
│   ├── ecs.tf                  # ECS 서비스, 태스크 정의
│   ├── alb.tf                  # ALB, 타겟 그룹
│   ├── iam.tf                  # 앱별 IAM 역할
│   └── outputs.tf
├── atlantis.yaml               # ⭐ 앱 레포 전용 Atlantis 설정
└── .github/workflows/
    ├── terraform-plan.yml      # ⭐ 인프라 검증
    ├── terraform-apply.yml     # ⭐ 인프라 배포
    └── deploy.yml              # 앱 배포
```

**특징**:
- ✅ 애플리케이션 팀 완전 자율성
- ✅ 앱 코드와 인프라가 같은 레포 (GitOps)
- ✅ 병렬 작업 가능
- ❌ 의존성 관리 복잡 (SSM Parameter Store)
- ❌ Governance 중복 적용 필요
- ❌ 일관성 유지 어려움

---

### 3. 하이브리드-라이트 (Hybrid-Lite)

```
📦 Infrastructure 레포 (공유 인프라 + ECR)
├── terraform/
│   ├── bootstrap/
│   ├── kms/
│   ├── network/
│   ├── rds/
│   ├── secrets/
│   ├── monitoring/
│   └── ecr/                    # ⭐ 모든 ECR 중앙 관리
│       ├── fileflow/
│       ├── api-server/
│       └── worker/
└── outputs-to-ssm/

📦 FileFlow 앱 레포
├── app/
├── docker/
├── terraform/                  # ⭐ ECS/ALB만
│   ├── data.tf                 # ECR ARN 참조
│   ├── ecs.tf
│   ├── alb.tf
│   └── iam.tf
├── atlantis.yaml
└── .github/workflows/
```

**특징**:
- ✅ ECR은 중앙에서 통합 관리 (보안 스캔, 정책)
- ✅ ECS/ALB는 앱 팀이 자율 관리
- ⚖️ 절충안 (복잡도 vs 자율성)

---

## 의존성 관리 패턴

### 중앙 집중형 (현재)
```hcl
# Infrastructure 레포: terraform/ecr/fileflow/main.tf
resource "aws_ecr_repository" "fileflow" {
  name = "fileflow"
  # ...
}

# 같은 레포 내에서 직접 참조 가능
```

### 하이브리드
```hcl
# Infrastructure 레포: terraform/outputs-to-ssm/main.tf
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/infrastructure/network/vpc_id"
  type  = "String"
  value = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/infrastructure/network/private_subnet_ids"
  type  = "StringList"
  value = join(",", data.terraform_remote_state.network.outputs.private_subnet_ids)
}

# FileFlow 앱 레포: terraform/data.tf
data "aws_ssm_parameter" "vpc_id" {
  name = "/infrastructure/network/vpc_id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/infrastructure/network/private_subnet_ids"
}

locals {
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
}

# ECS 서비스에서 사용
resource "aws_ecs_service" "fileflow" {
  network_configuration {
    subnets = local.private_subnet_ids
  }
}
```

---

## Atlantis 설정 비교

### 중앙 집중형 (현재)

**Infrastructure 레포 atlantis.yaml**:
```yaml
projects:
  - name: ecr-fileflow-prod
    dir: terraform/ecr/fileflow
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
```

**FileFlow 앱 레포**: atlantis.yaml 없음

---

### 하이브리드

**Infrastructure 레포 atlantis.yaml** (공유 인프라만):
```yaml
projects:
  - name: network-prod
    dir: terraform/network
  - name: rds-prod
    dir: terraform/rds
  # ECR, ECS 등 앱별 인프라는 제거
```

**FileFlow 앱 레포 atlantis.yaml** (앱 인프라):
```yaml
version: 3

automerge: false
parallel_plan: false
parallel_apply: false

projects:
  - name: fileflow-ecr-prod
    dir: terraform/ecr
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]

  - name: fileflow-ecs-prod
    dir: terraform/ecs
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
```

**주의**: Atlantis GitHub App은 **레포별로 atlantis.yaml 존재 여부로 활성화**

---

## GitHub Actions 워크플로우 비교

### 중앙 집중형 (현재)

**Infrastructure 레포**:
- ✅ terraform-plan.yml (모든 모듈)
- ✅ terraform-apply-and-deploy.yml (모든 모듈)
- ✅ infra-checks.yml (governance)

**FileFlow 앱 레포**:
- ✅ build-and-push.yml (ECR 푸시만)
- ✅ deploy.yml (ECS 배포만)

---

### 하이브리드

**Infrastructure 레포**:
- ✅ terraform-plan.yml (공유 인프라만)
- ✅ terraform-apply.yml (공유 인프라만)
- ✅ infra-checks.yml (governance)

**FileFlow 앱 레포**:
- ✅ terraform-plan.yml (앱 인프라)
- ✅ terraform-apply.yml (앱 인프라)
- ✅ infra-checks.yml (governance - 재사용)
- ✅ build-and-push.yml (ECR 푸시)
- ✅ deploy.yml (ECS 배포)

---

## 권장 선택 기준

### 중앙 집중형을 선택하는 경우

✅ **다음 조건에 해당하면 중앙 집중형 유지 권장**:
- 소규모 조직 (1-2개 인프라 팀)
- 애플리케이션 수 적음 (< 10개)
- 엄격한 인프라 통제 필요
- 일관성이 최우선
- 인프라 변경 빈도 낮음

**예시 조직**:
- 스타트업 초기 단계
- 플랫폼 팀 1개 + 앱 팀 2-3개
- 규제 산업 (금융, 의료)

---

### 하이브리드를 선택하는 경우

✅ **다음 조건에 해당하면 하이브리드 전환 권장**:
- 대규모 조직 (여러 개 개발 팀)
- 애플리케이션 수 많음 (> 10개)
- 팀 자율성 중요
- 빠른 배포 주기
- 마이크로서비스 아키텍처

**예시 조직**:
- 스케일업 단계
- 플랫폼 팀 1개 + 앱 팀 10개+
- DevOps 성숙도 높음

---

## 전환 가이드 (중앙 집중형 → 하이브리드)

### Phase 1: 준비 (Infrastructure 레포)

1. **SSM Parameter Store 설정**
   ```hcl
   # terraform/outputs-to-ssm/main.tf
   resource "aws_ssm_parameter" "vpc_id" {
     name  = "/infrastructure/network/vpc_id"
     type  = "String"
     value = data.terraform_remote_state.network.outputs.vpc_id
   }
   ```

2. **Governance Validators 모듈화**
   ```bash
   # 재사용 가능하도록 분리
   scripts/governance/
   ├── check-tags.sh
   ├── check-encryption.sh
   └── check-naming.sh
   ```

3. **atlantis.yaml 수정**
   - 앱별 프로젝트 제거
   - 공유 인프라만 유지

### Phase 2: 앱 레포 설정 (FileFlow)

1. **Terraform 디렉토리 생성**
   ```bash
   mkdir -p terraform/{ecr,ecs,alb,iam}
   ```

2. **Backend 설정**
   ```hcl
   # terraform/backend.tf
   terraform {
     backend "s3" {
       bucket         = "prod-connectly"
       key            = "fileflow/terraform.tfstate"
       region         = "ap-northeast-2"
       encrypt        = true
       dynamodb_table = "prod-connectly-tf-lock"
     }
   }
   ```

3. **Data Sources 설정**
   ```hcl
   # terraform/data.tf
   data "aws_ssm_parameter" "vpc_id" {
     name = "/infrastructure/network/vpc_id"
   }
   ```

4. **atlantis.yaml 생성**

5. **GitHub Actions 워크플로우 복사**
   - Infrastructure 레포에서 복사
   - 경로만 수정

### Phase 3: 마이그레이션

1. **State 마이그레이션**
   ```bash
   # Infrastructure 레포에서 state 제거
   terraform state rm aws_ecr_repository.fileflow

   # FileFlow 앱 레포에서 import
   terraform import aws_ecr_repository.fileflow fileflow
   ```

2. **검증 및 테스트**

3. **점진적 전환**
   - 신규 앱부터 하이브리드로 시작
   - 기존 앱은 선택적 마이그레이션

---

## 결론 및 권장사항

### 현재 Infrastructure 레포 상태
- ✅ **중앙 집중형** (Centralized)
- ❌ **하이브리드 아님**

### 권장사항

#### 소규모 조직 (현재 단계)
→ **중앙 집중형 유지** 권장
- 현재 구조가 실용적
- 복잡도 낮음
- 거버넌스 강화 용이

#### 대규모 조직으로 성장 시
→ **하이브리드 전환** 고려
- 팀 자율성 증가
- 병렬 개발 가능
- 단, 복잡도 증가 감안

### 명칭 정리
- 현재: "중앙 집중형 인프라 관리"
- 전환 후: "하이브리드 인프라 관리"

**하이브리드라고 부르려면**: 앱 레포에 terraform/ 디렉토리와 atlantis.yaml이 있어야 합니다!
