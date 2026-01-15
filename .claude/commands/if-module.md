# Infrastructure Module Command

새로운 Terraform 모듈을 생성하거나 기존 모듈을 관리합니다.

## 사용법

```
/if:module <module-name> [options]
/if:module list
/if:module analyze <module-name>
```

## 옵션

- `--type <type>`: 모듈 타입 (compute|storage|network|security|monitoring|messaging)
- `--env <env>`: 대상 환경 (prod|stage|dev)
- `--copy-from <module>`: 기존 모듈 복사해서 시작
- `--with-example`: examples/ 디렉토리 포함

## 동작

### 새 모듈 생성 시

1. **구조 생성**
   ```
   terraform/modules/<module-name>/
   ├── README.md
   ├── main.tf
   ├── variables.tf
   ├── outputs.tf
   ├── versions.tf
   └── examples/
       └── basic/
           ├── main.tf
           └── variables.tf
   ```

2. **필수 거버넌스 적용**
   - `merge(local.required_tags)` 패턴 자동 적용
   - KMS 암호화 변수 포함
   - kebab-case 리소스명, snake_case 변수명

3. **검증 실행**
   - `terraform fmt` 자동 적용
   - `terraform validate` 실행
   - 거버넌스 규칙 체크

### 모듈 분석 시

1. **의존성 분석**: 다른 모듈과의 의존 관계 파악
2. **사용처 확인**: environments/에서 사용 현황
3. **거버넌스 준수**: 태그, 암호화, 네이밍 검증

## 기존 모듈 목록

| 카테고리 | 모듈명 | 설명 |
|---------|--------|------|
| compute | ecs-service | ECS 서비스 배포 |
| compute | lambda | Lambda 함수 |
| compute | bastion-ssm | SSM 기반 Bastion |
| storage | s3-bucket | S3 버킷 |
| storage | rds | RDS 인스턴스 |
| storage | dynamodb | DynamoDB 테이블 |
| storage | elasticache | ElastiCache 클러스터 |
| storage | ecr | ECR 레포지토리 |
| network | alb | Application Load Balancer |
| network | security-group | Security Group |
| network | route53-record | Route53 레코드 |
| network | cloudfront | CloudFront 배포 |
| network | waf | WAF 규칙 |
| security | iam-role-policy | IAM 역할/정책 |
| monitoring | cloudwatch-log-group | CloudWatch Log Group |
| monitoring | log-subscription-filter | 로그 구독 필터 |
| monitoring | adot-sidecar | ADOT 사이드카 |
| messaging | sns | SNS 토픽 |
| messaging | sqs | SQS 큐 |
| messaging | eventbridge | EventBridge 규칙 |
| messaging | messaging-pattern | 메시징 패턴 조합 |
| common | common-tags | 공통 태그 |
| common | ecs-task-role-observability | ECS 태스크 역할 |

## 예제

```bash
# 새 Lambda 모듈 생성
/if:module my-lambda --type compute --with-example

# 기존 모듈 분석
/if:module analyze ecs-service

# 모듈 목록 확인
/if:module list

# S3 모듈 기반으로 새 모듈 생성
/if:module my-storage --copy-from s3-bucket
```

## 거버넌스 체크리스트

모듈 생성/수정 시 자동으로 검증:

- [ ] `merge(local.required_tags)` 패턴 사용
- [ ] KMS 암호화 설정 (AES256 금지)
- [ ] 리소스명 kebab-case
- [ ] 변수명 snake_case
- [ ] 민감정보 하드코딩 없음
- [ ] README.md 포함
- [ ] variables.tf 설명 완비
- [ ] outputs.tf 필수 출력 정의

## Governance 정책 참조

모듈 생성 시 아래 OPA 정책을 자동으로 준수합니다:

```bash
# 필수 태그 정책
cat governance/policies/tagging/required_tags.rego

# 네이밍 정책
cat governance/policies/naming/resource_naming.rego

# 보안 그룹 정책 (network 모듈용)
cat governance/policies/security_groups/security_group_rules.rego

# 공개 리소스 정책 (storage 모듈용)
cat governance/policies/public_resources/public_access.rego
```

## 검증 실행

```bash
# 생성된 모듈 검증
./governance/scripts/validators/validate-terraform-file.sh terraform/modules/<module-name>/*.tf

# OPA 정책 검증
conftest test tfplan.json --config governance/configs/conftest.toml
```

## 관련 커맨드

- `/if:validate` - 거버넌스 검증
- `/if:shared` - 공유 리소스 관리
- `/if:atlantis` - Atlantis 작업
