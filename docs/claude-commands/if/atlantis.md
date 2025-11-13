# Infrastructure Atlantis Command

**Task**: Atlantis 설정을 자동으로 관리하고 새 프로젝트를 추가합니다.

## Atlantis 정보

- **설정 파일**: `/path/to/infrastructure/atlantis.yaml`
- **현재 프로젝트들**: bootstrap, kms, network, secrets, rds, cloudtrail, logging, monitoring, route53, acm, atlantis, ecr-fileflow, fileflow

## 실행 가능한 작업

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
