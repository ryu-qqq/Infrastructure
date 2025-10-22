# Shared Resources Reference Example

이 예제는 shared 패키지에서 생성된 공유 리소스를 다른 Terraform 모듈에서 참조하는 방법을 보여줍니다.

## 개요

Terraform Remote State를 사용하여 다음 패키지들의 출력을 참조:

- **shared**: 공통 태그, 설정
- **kms**: KMS 암호화 키
- **network**: VPC, 서브넷, 보안 그룹

## 공유 리소스 패턴

### 1. Remote State 참조

```hcl
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "ryuqqq-prod-tfstate"
    key    = "shared/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
```

### 2. 공유 태그 사용

```hcl
locals {
  required_tags = data.terraform_remote_state.shared.outputs.required_tags
}

resource "aws_s3_bucket" "example" {
  bucket = "example-bucket"

  tags = merge(
    local.required_tags,  # 공유 태그 사용
    {
      Component = "example"
    }
  )
}
```

### 3. KMS 키 참조

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = data.terraform_remote_state.kms.outputs.terraform_state_key_arn
    }
  }
}
```

### 4. Network 정보 참조

```hcl
# VPC ID
vpc_id = data.terraform_remote_state.network.outputs.vpc_id

# Private Subnets
private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

# Public Subnets
public_subnet_ids = data.terraform_remote_state.network.outputs.public_subnet_ids
```

## 사용 방법

### 1. Terraform 실행

```bash
terraform init
terraform plan
terraform apply
```

### 2. 출력 확인

```bash
# VPC 정보 확인
terraform output vpc_id
terraform output private_subnet_ids
terraform output public_subnet_ids
```

## 참조 가능한 공유 출력

### Shared 패키지

- `required_tags`: 거버넌스 필수 태그
- `common_settings`: 공통 설정

### KMS 패키지

- `terraform_state_key_arn`: Terraform State 암호화 키
- `rds_key_arn`: RDS 암호화 키
- `ecs_secrets_key_arn`: ECS Secrets 암호화 키
- `secrets_manager_key_arn`: Secrets Manager 암호화 키

### Network 패키지

- `vpc_id`: VPC ID
- `vpc_cidr`: VPC CIDR 블록
- `public_subnet_ids`: Public 서브넷 ID 목록
- `private_subnet_ids`: Private 서브넷 ID 목록
- `nat_gateway_ids`: NAT Gateway ID 목록

## Best Practices

### 1. State Isolation

```hcl
backend "s3" {
  bucket = "ryuqqq-prod-tfstate"
  key    = "your-service/terraform.tfstate"  # 서비스별 고유 키
  region = "ap-northeast-2"
}
```

### 2. 순환 참조 방지

- shared → network → rds 순서로 배포
- 역방향 참조 금지 (예: network → shared ❌)

### 3. 출력 문서화

공유 패키지의 outputs.tf에 명확한 description 작성:

```hcl
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}
```

## 주의사항

### 1. State 파일 의존성

- Remote State는 실시간 동기화되지 않음
- 공유 리소스 변경 후 `terraform refresh` 실행 필요

### 2. Backend 설정

- 모든 모듈이 같은 S3 버킷 사용
- 환경별로 다른 State 파일 키 사용

### 3. 권한 관리

terraform {
  backend "s3" {
    # 모든 모듈이 이 버킷에 읽기 권한 필요
    bucket = "ryuqqq-prod-tfstate"
  }
}
```

## 참고 자료

- [Terraform Remote State](https://www.terraform.io/docs/language/state/remote-state-data.html)
- [S3 Backend Configuration](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [Shared 패키지 문서](../../README.md)
