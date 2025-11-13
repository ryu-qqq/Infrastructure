# Infrastructure Atlantis Command

**Task**: Multi-Repo 아키텍처에서 Atlantis 설정을 자동으로 관리합니다.

## Multi-Repo Atlantis 아키텍처

```
중앙 Atlantis 서버 (ECS)
    ↓ (github.com/ryu-qqq/* 허용)
    ├─→ Infrastructure 레포 (atlantis.yaml) - 공유 인프라
    ├─→ FileFlow 레포 (atlantis.yaml) - FileFlow 인프라
    └─→ API Server 레포 (atlantis.yaml) - API Server 인프라
```

**핵심 개념**:
- 중앙 Atlantis 서버는 **모든 ryu-qqq 레포**를 허용
- 각 레포는 **자신의 atlantis.yaml**만 관리
- PR이 열리면 Atlantis가 해당 레포의 설정을 자동 감지

## 실행 가능한 작업

### 1. 애플리케이션 레포용 Atlantis 설정 생성 ⭐ **NEW**

**사용 시나리오**: FileFlow, API Server 등 애플리케이션 레포에서 사용

```bash
# FileFlow 레포에서
cd ~/fileflow
/if/atlantis init

# 또는 직접 실행
/path/to/infrastructure/scripts/atlantis/init-repo-atlantis.sh
```

**작동 방식**:
1. 🔍 `terraform/` 디렉토리 자동 스캔
2. 📋 감지된 프로젝트 표시 및 선택
3. ✅ `atlantis.yaml` 자동 생성
4. 📝 베스트 프랙티스 적용

**출력 예시**:
```
🔍 Scanning terraform directories...

  ✓ Found: terraform/ecr
  ✓ Found: terraform/alb
  ✓ Found: terraform/ecs-service
  ⊗ Found: terraform/dev (excluded by default)

📋 Detected Terraform Projects:

  [x] ecr-prod (terraform/ecr)
      Container Registry for FileFlow

  [x] alb-prod (terraform/alb)
      Application Load Balancer

  [x] ecs-service-prod (terraform/ecs-service)
      ECS Service deployment

  [ ] dev (terraform/dev)
      Development environment (usually skip)

? Include selected projects in atlantis.yaml? (Y/n): y
? Include excluded projects (dev/test)? (y/N): n

✅ Generated: atlantis.yaml
✅ Added 3 projects
```

**생성되는 atlantis.yaml**:
```yaml
version: 3

automerge: false
delete_source_branch_on_merge: false
parallel_plan: true
parallel_apply: false

projects:
  # ============================================================================
  # Container Registry
  # ============================================================================

  # Container Registry for FileFlow
  - name: ecr-prod
    dir: terraform/ecr
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default

  # ============================================================================
  # Load Balancing & CDN
  # ============================================================================

  # Application Load Balancer
  - name: alb-prod
    dir: terraform/alb
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default

  # ============================================================================
  # Application Infrastructure
  # ============================================================================

  # ECS Service deployment
  - name: ecs-service-prod
    dir: terraform/ecs-service
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default

workflows:
  default:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - apply
```

### 2. Infrastructure 레포에 프로젝트 추가 (Legacy)

### 1. 현재 Atlantis 프로젝트 목록 확인
```bash
cd /path/to/infrastructure
grep -A 3 "^  - name:" atlantis.yaml | grep "name:"
```

### 2. 새 프로젝트를 Atlantis에 추가

새 프로젝트를 추가할 때 다음 템플릿을 사용하세요:

```yaml
# ============================================================================
# {Category Name} ({카테고리 설명})
# ============================================================================

# {Service Name} - {Description}
- name: {service-name}-prod
  dir: terraform/{service-name}
  workspace: default
  autoplan:
    when_modified: ["*.tf", "*.tfvars"]
    enabled: true
  apply_requirements: ["approved", "mergeable"]
  workflow: default
```

### 3. Atlantis 설정 검증
```bash
cd /path/to/infrastructure
# Atlantis 설정 파일 구문 검증
atlantis validate atlantis.yaml

# 또는 YAML 구문만 검증
yamllint atlantis.yaml
```

### 4. 프로젝트 추가 자동화 스크립트 실행
```bash
cd /path/to/infrastructure
./scripts/atlantis/add-project.sh {service-name} {category} "{description}"
```

## 프로젝트 추가 예시

### API Server 추가
```bash
# 1. Terraform 구성 생성
mkdir -p terraform/api-server
cd terraform/api-server

# 2. 기본 파일 생성
cat > main.tf << 'EOF'
terraform {
  backend "s3" {
    bucket         = "ryuqqq-prod-tfstate"
    key            = "api-server/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
    kms_key_id     = "alias/terraform-state"
  }
}

# ... 리소스 정의
EOF

# 3. Atlantis 설정에 추가
./scripts/atlantis/add-project.sh api-server "Application Infrastructure" "API Server - REST API Service"
```

## Atlantis 프로젝트 구조

현재 구조:
```
Shared Infrastructure (공유 인프라)
├── bootstrap-prod
├── kms-prod
├── network-prod
├── secrets-prod
├── rds-prod
├── cloudtrail-prod
├── logging-prod
├── monitoring-prod
├── route53-prod
└── acm-prod

Platform Infrastructure (플랫폼 인프라)
├── atlantis-prod
└── atlantis-test

Container Registry (컨테이너 레지스트리)
└── ecr-fileflow-prod

Application Infrastructure (애플리케이션 인프라)
└── fileflow-prod
```

## 주의사항

- 새 프로젝트 추가 시 카테고리를 명확히 지정하세요
- `apply_requirements`에 `["approved", "mergeable"]`를 포함하여 승인 후 배포되도록 하세요
- 초기 배포 시에만 `apply_requirements`를 주석 처리할 수 있습니다
- Atlantis 서버를 재시작하지 않아도 설정이 자동으로 반영됩니다
