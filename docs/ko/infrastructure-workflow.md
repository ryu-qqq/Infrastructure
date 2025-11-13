# Infrastructure Workflow - Claude 통합 가이드

이 문서는 infrastructure 프로젝트와 Claude Code의 통합 워크플로우를 설명합니다.

## 📋 목차

1. [개요](#개요)
2. [Claude 커맨드 사용법](#claude-커맨드-사용법)
3. [모듈 관리 워크플로우](#모듈-관리-워크플로우)
4. [Atlantis 프로젝트 추가 워크플로우](#atlantis-프로젝트-추가-워크플로우)
5. [문제 해결](#문제-해결)

---

## 개요

infrastructure 프로젝트는 Terraform 모듈을 중앙 집중식으로 관리하여 여러 프로젝트에서 재사용할 수 있도록 합니다.

### 주요 기능

- ✅ **모듈 검증**: 모든 모듈의 구조와 유효성을 자동으로 검증
- 🔄 **Atlantis 통합**: 새 프로젝트를 Atlantis에 자동으로 추가
- 📦 **재사용 가능한 모듈**: 표준화된 모듈을 다른 프로젝트에서 사용
- 🛡️ **거버넌스 규칙**: 태그, 암호화, 네이밍 컨벤션 자동 검증

### 디렉토리 구조

```
infrastructure/
├── terraform/
│   ├── modules/          # 재사용 가능한 모듈
│   │   ├── alb/
│   │   ├── ecs-service/
│   │   ├── rds/
│   │   └── ...
│   ├── bootstrap/        # 실제 인프라 구성
│   ├── network/
│   └── ...
├── scripts/
│   ├── validators/       # 검증 스크립트
│   └── atlantis/        # Atlantis 관리 스크립트
└── atlantis.yaml        # Atlantis 설정
```

---

## Claude 커맨드 사용법

Claude Code에서 `/if/` 커맨드를 사용하여 인프라를 관리할 수 있습니다.

### 1. 모듈 검증: `/if/validate`

모든 모듈 또는 특정 모듈의 유효성을 검증합니다.

```bash
# 전체 모듈 검증
/if/validate

# 특정 모듈만 검증
/if/validate alb
/if/validate ecs-service
```

**검증 항목:**
- ✅ 필수 파일 존재 (main.tf, variables.tf, outputs.tf, versions.tf)
- ✅ terraform init 성공
- ✅ terraform validate 성공
- ✅ 예제 코드 유효성
- ✅ 거버넌스 규칙 (태그, 암호화, 네이밍)

### 2. 모듈 관리: `/if/module`

모듈을 조회하고 다른 프로젝트에서 사용합니다.

```bash
# 모듈 목록 조회
/if/module list

# 특정 모듈 구조 보기
/if/module show alb

# 모듈을 다른 프로젝트로 복사
/if/module copy alb /path/to/target-project
```

### 3. Atlantis 프로젝트 추가: `/if/atlantis`

새 프로젝트를 Atlantis에 자동으로 추가합니다.

```bash
# 새 프로젝트 추가
/if/atlantis add api-server "Application Infrastructure" "API Server - REST API Service"

# 현재 프로젝트 목록 확인
/if/atlantis list
```

---

## 모듈 관리 워크플로우

### 시나리오 1: 기존 모듈을 다른 프로젝트에서 사용

1. **모듈 검증**
   ```bash
   /if/validate ecs-service
   ```

2. **심볼릭 링크 생성 (권장)**
   ```bash
   cd /path/to/your-project
   mkdir -p terraform/modules
   ln -s /path/to/infrastructure/terraform/modules/ecs-service \
         terraform/modules/ecs-service
   ```

3. **모듈 사용**
   ```hcl
   # your-project/terraform/main.tf
   module "ecs_service" {
     source = "./modules/ecs-service"

     cluster_id      = var.cluster_id
     service_name    = "api-service"
     task_definition = aws_ecs_task_definition.app.arn
     desired_count   = 2

     common_tags = module.common_tags.tags
   }
   ```

### 시나리오 2: 새 모듈 생성

1. **모듈 디렉토리 생성**
   ```bash
   cd /path/to/infrastructure
   mkdir -p terraform/modules/my-new-module/{examples/basic,examples/advanced}
   ```

2. **필수 파일 생성**
   ```bash
   cd terraform/modules/my-new-module
   touch main.tf variables.tf outputs.tf versions.tf README.md
   ```

3. **모듈 구현**
   ```hcl
   # main.tf
   resource "aws_..." "example" {
     # ...

     tags = merge(
       local.required_tags,
       {
         Name = var.name
       }
     )
   }
   ```

4. **검증**
   ```bash
   /if/validate my-new-module
   ```

5. **커밋 및 푸시**
   ```bash
   git add terraform/modules/my-new-module
   git commit -m "feat: Add my-new-module"
   git push
   ```

---

## Atlantis 프로젝트 추가 워크플로우

### 시나리오 3: 새 서비스를 위한 인프라 추가

1. **Terraform 구성 생성**
   ```bash
   cd /path/to/infrastructure
   mkdir -p terraform/api-server
   ```

2. **기본 설정 파일 작성**
   ```hcl
   # terraform/api-server/main.tf
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

   # 공통 태그 모듈
   module "common_tags" {
     source = "../modules/common-tags"

     environment = "prod"
     service     = "api-server"
     team        = "backend-team"
     owner       = "backend@example.com"
     cost_center = "engineering"
   }

   # ECS 서비스 모듈
   module "ecs_service" {
     source = "../modules/ecs-service"

     cluster_id         = data.aws_ecs_cluster.main.id
     service_name       = "api-server"
     task_definition    = aws_ecs_task_definition.app.arn
     desired_count      = 2

     common_tags = module.common_tags.tags
   }
   ```

3. **Atlantis에 프로젝트 추가**
   ```bash
   /if/atlantis add api-server "Application Infrastructure" "API Server - REST API Service"
   ```

4. **검증**
   ```bash
   cd terraform/api-server
   terraform init
   terraform validate
   terraform plan
   ```

5. **커밋 및 PR 생성**
   ```bash
   git add atlantis.yaml terraform/api-server
   git commit -m "feat: Add api-server infrastructure"
   git push origin feature/api-server
   ```

6. **PR에서 Atlantis가 자동으로 plan 실행**
   - Atlantis가 자동으로 `terraform plan`을 실행
   - PR 코멘트에 plan 결과가 표시됨
   - 리뷰 및 승인 후 merge

7. **Merge 후 자동 배포**
   - Atlantis가 자동으로 `terraform apply` 실행
   - 인프라가 배포됨

---

## 문제 해결

### 모듈 검증 실패

**문제**: `/if/validate` 실행 시 오류 발생

**해결 방법**:

1. **필수 파일 누락**
   ```bash
   # 누락된 파일 확인
   ls terraform/modules/my-module/

   # 필수 파일 생성
   touch terraform/modules/my-module/versions.tf
   ```

2. **거버넌스 규칙 위반**
   - 태그 패턴: `merge(local.required_tags)` 사용
   - 암호화: KMS 키 사용 (AES256 금지)
   - 네이밍: 리소스는 kebab-case, 변수는 snake_case

3. **Terraform 유효성 오류**
   ```bash
   cd terraform/modules/my-module
   terraform init
   terraform validate
   # 오류 메시지 확인 후 수정
   ```

### Atlantis 프로젝트 추가 실패

**문제**: 프로젝트 추가 스크립트 실행 시 오류

**해결 방법**:

1. **이미 존재하는 프로젝트**
   ```bash
   # atlantis.yaml에서 중복 확인
   grep "name: api-server-prod" atlantis.yaml
   ```

2. **잘못된 카테고리**
   ```bash
   # 유효한 카테고리 확인
   ./scripts/atlantis/add-project.sh
   ```

3. **YAML 구문 오류**
   ```bash
   # YAML 검증
   python3 -c "import yaml; yaml.safe_load(open('atlantis.yaml'))"
   ```

### 심볼릭 링크 오류

**문제**: 다른 프로젝트에서 모듈 심볼릭 링크가 작동하지 않음

**해결 방법**:

1. **절대 경로 사용**
   ```bash
   ln -s /path/to/infrastructure/terraform/modules/ecs-service \
         ./terraform/modules/ecs-service
   ```

2. **심볼릭 링크 확인**
   ```bash
   ls -la terraform/modules/
   # lrwxr-xr-x  ... ecs-service -> /path/to/infrastructure/...
   ```

3. **대안: 직접 복사**
   ```bash
   cp -r /path/to/infrastructure/terraform/modules/ecs-service \
         ./terraform/modules/
   ```

---

## 자동화 스크립트 위치

모든 스크립트는 infrastructure 프로젝트에 위치합니다:

```
/path/to/infrastructure/
├── scripts/
│   ├── validators/
│   │   ├── validate-modules.sh          # 모듈 검증
│   │   └── validate-terraform-file.sh   # 파일 검증
│   └── atlantis/
│       └── add-project.sh               # Atlantis 프로젝트 추가
└── atlantis.yaml                        # Atlantis 설정
```

---

## 추가 리소스

- [Terraform 모듈 문서](../modules/README.md)
- [거버넌스 규칙](.claude/INFRASTRUCTURE_RULES.md)
- [Atlantis 문서](https://www.runatlantis.io/)

---

**작성일**: 2025-01-13
**작성자**: Infrastructure Team
**버전**: 1.0.0
