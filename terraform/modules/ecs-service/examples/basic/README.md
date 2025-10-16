# Basic Example

이 예제는 최소한의 설정으로 ECS Fargate 서비스를 배포하는 방법을 보여줍니다.

## 포함된 리소스

- ECS Cluster
- ECS Service (1개 태스크)
- ECS Task Definition
- CloudWatch Log Group
- Security Group
- IAM Roles (Execution & Task)

## 사용 방법

1. 변수 설정:

```bash
export TF_VAR_vpc_id="vpc-xxxxx"
```

2. Terraform 초기화 및 배포:

```bash
terraform init
terraform plan
terraform apply
```

3. 배포 확인:

```bash
aws ecs list-services --cluster my-api-dev
aws ecs describe-services --cluster my-api-dev --services my-api
```

4. 로그 확인:

```bash
aws logs tail /ecs/my-api --follow
```

## 정리

```bash
terraform destroy
```

## 커스터마이징

`variables.tf`의 기본값을 수정하거나 `.tfvars` 파일을 생성하여 설정을 변경할 수 있습니다:

```hcl
# terraform.tfvars
environment     = "dev"
service_name    = "my-custom-service"
container_image = "my-ecr-repo/app:v1.0.0"
container_port  = 8080
```
