# Infrastructure Module Command

**Task**: infrastructure 프로젝트의 Terraform 모듈을 관리합니다 (조회, 생성, 복사).

## 프로젝트 정보

- **경로**: `/Users/sangwon-ryu/infrastructure`
- **모듈 위치**: `terraform/modules/`
- **사용 가능한 모듈들**:
  - alb
  - cloudfront
  - cloudwatch-log-group
  - common-tags
  - ecs-service
  - elasticache
  - iam-role-policy
  - lambda
  - messaging-pattern
  - rds
  - route53-record
  - s3-bucket
  - security-group
  - sns
  - sqs
  - waf

## 실행 가능한 작업

### 1. 모듈 목록 조회
```bash
cd /Users/sangwon-ryu/infrastructure
ls -la terraform/modules/
```

### 2. 특정 모듈 구조 보기
```bash
cd /Users/sangwon-ryu/infrastructure
tree terraform/modules/{module-name}
```

### 3. 모듈을 다른 프로젝트로 복사
```bash
# 심볼릭 링크 생성 (권장)
ln -s /Users/sangwon-ryu/infrastructure/terraform/modules/{module-name} {target-project}/terraform/modules/

# 또는 직접 복사
cp -r /Users/sangwon-ryu/infrastructure/terraform/modules/{module-name} {target-project}/terraform/modules/
```

### 4. 새 모듈 생성 템플릿
```bash
cd /Users/sangwon-ryu/infrastructure/terraform/modules
mkdir -p {new-module}/{examples/basic,examples/advanced}
touch {new-module}/{main.tf,variables.tf,outputs.tf,versions.tf,README.md}
```

## 모듈 사용 예시

### ALB 모듈 사용
```hcl
module "alb" {
  source = "../../modules/alb"

  name               = "api-alb"
  vpc_id             = var.vpc_id
  subnets            = var.public_subnet_ids
  security_group_ids = [aws_security_group.alb.id]

  common_tags = module.common_tags.tags
}
```

### ECS Service 모듈 사용
```hcl
module "ecs_service" {
  source = "../../modules/ecs-service"

  cluster_id         = var.cluster_id
  service_name       = "api-service"
  task_definition    = aws_ecs_task_definition.app.arn
  desired_count      = 2

  common_tags = module.common_tags.tags
}
```

## 주의사항

- 모듈 사용 전 반드시 `/if/validate {module-name}` 으로 검증하세요
- 새 모듈 생성 시 필수 파일들을 모두 포함해야 합니다
- 거버넌스 규칙을 준수해야 합니다 (태그, 암호화, 네이밍)
