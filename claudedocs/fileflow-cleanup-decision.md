# FileFlow 리소스 정리 결정 가이드

## 📊 현재 상태 분석

### ✅ Infrastructure 레포에 존재하는 FileFlow 리소스

#### 1. `terraform/ecr/fileflow/` (실제 배포됨 ✅)

**파일 목록**:
```
terraform/ecr/fileflow/
├── main.tf           # ECR 레포지토리 정의
├── data.tf           # Data sources
├── locals.tf         # Local values
├── outputs.tf        # Outputs
├── variables.tf      # Variables
└── provider.tf       # Provider 설정
```

**배포된 리소스** (Terraform State 확인):
```
✅ aws_ecr_repository.fileflow
✅ aws_ecr_lifecycle_policy.fileflow
✅ aws_ecr_repository_policy.fileflow
✅ aws_ssm_parameter.fileflow-repository-url
✅ data.aws_caller_identity.current
✅ data.aws_ssm_parameter.ecs-secrets-key-arn
```

**AWS 실제 리소스**:
```json
{
  "repositoryName": "fileflow",
  "repositoryUri": "646886795421.dkr.ecr.ap-northeast-2.amazonaws.com/fileflow",
  "createdAt": "2025-10-21T17:29:49",
  "imageTagMutability": "MUTABLE",
  "imageScanningConfiguration": {
    "scanOnPush": true
  },
  "encryptionConfiguration": {
    "encryptionType": "KMS"
  }
}
```

#### 2. `terraform/fileflow/` (존재하지 않음 ❌)

**확인 결과**: 디렉토리 없음
- ECS 서비스, ALB 등은 아직 생성되지 않음
- atlantis.yaml에 `fileflow-prod` 프로젝트 정의는 있지만 실제 코드는 없음

#### 3. `atlantis.yaml` 참조

**Line 149-156**: ECR FileFlow 프로젝트
```yaml
- name: ecr-fileflow-prod
  dir: terraform/ecr/fileflow  # ✅ 실제 존재
  workspace: default
  autoplan:
    when_modified: ["*.tf", "*.tfvars"]
    enabled: true
  apply_requirements: ["approved", "mergeable"]
```

**Line 163-170**: FileFlow ECS 서비스 프로젝트
```yaml
- name: fileflow-prod
  dir: terraform/fileflow  # ❌ 디렉토리 없음
  workspace: default
  autoplan:
    when_modified: ["*.tf", "*.tfvars"]
    enabled: true
  # apply_requirements: ["approved", "mergeable"]  # Temporarily disabled
```

#### 4. `.github/workflows/terraform-apply-and-deploy.yml`

**Line 126-137**: ECR FileFlow 배포 스텝
```yaml
- name: Terraform Init - ECR FileFlow
  working-directory: terraform/ecr/fileflow  # ✅ 실제 존재
  run: terraform init

- name: Terraform Apply - ECR FileFlow
  working-directory: terraform/ecr/fileflow
  run: terraform apply -auto-approve
```

---

## 🤔 지워도 되는가? → 상황에 따라 다름

### Option 1: 하이브리드-라이트 (ECR 중앙 관리) - **권장** ✅

**결정**: `terraform/ecr/fileflow/` **유지**

**이유**:
1. **보안 관리 집중화**
   - ECR은 이미지 스캔, 취약점 관리가 중요
   - 중앙에서 lifecycle policy, 암호화 정책 통합 관리
   - KMS 키 관리 단순화

2. **이미 배포된 리소스**
   - AWS에 실제 ECR 레포지토리 존재
   - Terraform state 존재
   - 마이그레이션 불필요

3. **복잡도 감소**
   - ECR은 변경 빈도가 낮음
   - 앱 레포에서는 ECS, ALB만 관리하면 충분

**필요한 작업**:
- ✅ `terraform/ecr/fileflow/` 유지
- ✅ `atlantis.yaml`에서 `ecr-fileflow-prod` 프로젝트 유지
- ❌ `atlantis.yaml`에서 `fileflow-prod` 프로젝트 **제거** (디렉토리 없음)
- ✅ GitHub Actions workflow에서 ECR 스텝 유지

---

### Option 2: 완전 하이브리드 (ECR도 앱 레포) - **고급** ⚠️

**결정**: `terraform/ecr/fileflow/` **삭제 및 마이그레이션**

**이유**:
1. 완전한 애플리케이션 자율성
2. 앱 레포에서 ECR부터 ECS까지 모든 인프라 관리
3. GitOps 완벽 구현

**필요한 작업**:
1. **State 마이그레이션**
   ```bash
   # Infrastructure 레포에서 state 제거
   cd terraform/ecr/fileflow
   terraform state rm aws_ecr_repository.fileflow
   terraform state rm aws_ecr_lifecycle_policy.fileflow
   terraform state rm aws_ecr_repository_policy.fileflow
   terraform state rm aws_ssm_parameter.fileflow-repository-url

   # FileFlow 앱 레포에서 import
   cd fileflow-app/terraform
   terraform import aws_ecr_repository.fileflow fileflow
   # ... (나머지 리소스들도 import)
   ```

2. **디렉토리 삭제**
   ```bash
   cd /Users/sangwon-ryu/infrastructure
   rm -rf terraform/ecr/fileflow
   ```

3. **atlantis.yaml 수정**
   - `ecr-fileflow-prod` 프로젝트 제거
   - `fileflow-prod` 프로젝트 제거

4. **GitHub Actions 수정**
   - ECR FileFlow 스텝 제거

**주의사항**:
- ⚠️ State 마이그레이션 실수 시 리소스 재생성 위험
- ⚠️ ECR 이미지 손실 가능성 (백업 필수)
- ⚠️ 다운타임 발생 가능

---

## 📋 권장 방안: 하이브리드-라이트

### Infrastructure 레포에서 관리 (중앙)
```
✅ terraform/ecr/fileflow/  # ECR 레포지토리
✅ terraform/kms/           # KMS 키
✅ terraform/network/       # VPC, 서브넷
✅ terraform/rds/           # 공유 데이터베이스
✅ terraform/secrets/       # Secrets Manager
✅ terraform/monitoring/    # CloudWatch, SNS
```

### FileFlow 앱 레포에서 관리 (분산)
```
📦 fileflow-app/terraform/
├── ecs-cluster.tf          # ECS 클러스터 (선택)
├── ecs-task-definition.tf  # 태스크 정의
├── ecs-service.tf          # ECS 서비스
├── alb.tf                  # ALB, 타겟 그룹
├── iam.tf                  # IAM 역할
├── security-groups.tf      # 보안 그룹
├── cloudwatch.tf           # 로그, 알람
└── data.tf                 # ECR URL 참조
```

### FileFlow 앱 레포에서 ECR 참조 방법

**data.tf**:
```hcl
# ECR Repository URL from SSM Parameter Store
data "aws_ssm_parameter" "fileflow_ecr_url" {
  name = "/shared/ecr/fileflow-repository-url"
}

locals {
  ecr_repository_url = data.aws_ssm_parameter.fileflow_ecr_url.value
}
```

**ecs-task-definition.tf**:
```hcl
resource "aws_ecs_task_definition" "fileflow" {
  # ...
  container_definitions = jsonencode([
    {
      name  = "fileflow"
      image = "${local.ecr_repository_url}:${var.image_tag}"
      # ...
    }
  ])
}
```

---

## ✅ 실행 계획: 하이브리드-라이트 전환

### Phase 1: atlantis.yaml 정리 (Infrastructure 레포)

**삭제할 프로젝트**:
```yaml
# ❌ 삭제 - 디렉토리가 존재하지 않음
- name: fileflow-prod
  dir: terraform/fileflow  # 없는 디렉토리
```

**유지할 프로젝트**:
```yaml
# ✅ 유지 - 실제 리소스 배포됨
- name: ecr-fileflow-prod
  dir: terraform/ecr/fileflow
```

**수정된 atlantis.yaml**:
```yaml
# ============================================================================
# Container Registry (컨테이너 레지스트리)
# ============================================================================

# ECR - FileFlow Container Registry
- name: ecr-fileflow-prod
  dir: terraform/ecr/fileflow
  workspace: default
  autoplan:
    when_modified: ["*.tf", "*.tfvars"]
    enabled: true
  apply_requirements: ["approved", "mergeable"]
  workflow: default

# ============================================================================
# Application Infrastructure (애플리케이션 인프라)
# ============================================================================

# 주석: FileFlow ECS 서비스는 FileFlow 앱 레포에서 관리
# 참조: https://github.com/org/fileflow/tree/main/terraform
```

---

### Phase 2: ECR outputs SSM export 확인

**terraform/ecr/fileflow/outputs.tf 확인 필요**:
```hcl
# 이미 존재하는지 확인
resource "aws_ssm_parameter" "fileflow-repository-url" {
  name  = "/shared/ecr/fileflow-repository-url"
  value = aws_ecr_repository.fileflow.repository_url
  # ...
}
```

**만약 없다면 추가**:
```hcl
# terraform/ecr/fileflow/outputs.tf에 추가
resource "aws_ssm_parameter" "fileflow-repository-url" {
  name        = "/shared/ecr/fileflow-repository-url"
  description = "FileFlow ECR repository URL for cross-stack references"
  type        = "String"
  value       = aws_ecr_repository.fileflow.repository_url

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-repository-url-export"
      Component = "ecr"
    }
  )
}
```

---

### Phase 3: FileFlow 앱 레포 설정

**1. ECR URL 참조**:
```hcl
# terraform/data.tf
data "aws_ssm_parameter" "fileflow_ecr_url" {
  name = "/shared/ecr/fileflow-repository-url"
}

locals {
  ecr_repository_url = data.aws_ssm_parameter.fileflow_ecr_url.value
}
```

**2. ECS 태스크 정의에서 사용**:
```hcl
# terraform/ecs-task-definition.tf
resource "aws_ecs_task_definition" "fileflow" {
  container_definitions = jsonencode([
    {
      image = "${local.ecr_repository_url}:${var.image_tag}"
    }
  ])
}
```

---

## 📝 체크리스트

### Infrastructure 레포 작업
- [ ] `atlantis.yaml`에서 `fileflow-prod` 프로젝트 제거 (dir: terraform/fileflow)
- [ ] `atlantis.yaml`에서 `ecr-fileflow-prod` 프로젝트 **유지**
- [ ] `terraform/ecr/fileflow/outputs.tf`에 SSM Parameter export 확인/추가
- [ ] `.github/workflows/terraform-apply-and-deploy.yml`에서 ECR FileFlow 스텝 **유지**
- [ ] README 업데이트 (하이브리드 구조 설명)

### FileFlow 앱 레포 작업
- [ ] `terraform/data.tf`에 ECR URL 참조 추가
- [ ] `terraform/ecs-task-definition.tf`에서 ECR 이미지 사용
- [ ] `atlantis.yaml` 생성 (ECS, ALB 등만)
- [ ] GitHub Actions workflows 설정
- [ ] README 작성

### 검증
- [ ] Infrastructure 레포 `atlantis plan` 성공
- [ ] FileFlow 앱 레포 `terraform plan` 성공
- [ ] ECR URL SSM Parameter 존재 확인
- [ ] ECS 태스크 정의에서 ECR 이미지 참조 확인

---

## 🎯 결론 및 권장사항

### **권장**: ECR은 Infrastructure 레포에 유지 ✅

**이유**:
1. ✅ 이미 배포되어 있음 (마이그레이션 불필요)
2. ✅ ECR은 변경 빈도 낮음 (보안 정책, lifecycle만)
3. ✅ 중앙에서 보안 스캔, 암호화 정책 관리
4. ✅ 복잡도 감소 (state 마이그레이션 위험 없음)
5. ✅ 앱 레포는 ECS, ALB 등만 집중

**삭제할 것**:
- ❌ `atlantis.yaml`의 `fileflow-prod` 프로젝트 (dir: terraform/fileflow - 디렉토리 없음)

**유지할 것**:
- ✅ `terraform/ecr/fileflow/` 전체
- ✅ `atlantis.yaml`의 `ecr-fileflow-prod` 프로젝트
- ✅ GitHub Actions ECR FileFlow 스텝

**추가할 것** (선택):
- 📝 `terraform/ecr/fileflow/outputs.tf`에 SSM Parameter export (필요 시)

다음 단계로 `atlantis.yaml` 수정 작업을 진행할까요?
