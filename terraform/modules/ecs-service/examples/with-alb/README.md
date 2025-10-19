# ALB와 함께 사용하는 ECS Service 예제

이 예제는 Application Load Balancer(ALB)와 통합된 ECS Fargate 서비스를 배포하는 방법을 보여줍니다. 실제 운영 환경에서 웹 애플리케이션이나 API 서비스를 배포하는 일반적인 시나리오입니다.

## 아키텍처

```
Internet
    |
    v
Application Load Balancer (Public Subnets)
    |
    v
ECS Fargate Tasks (Private Subnets)
    |
    v
CloudWatch Logs
```

## 주요 기능

- ✅ Application Load Balancer를 통한 인터넷 접근
- ✅ HTTP → HTTPS 자동 리다이렉트
- ✅ ECS Fargate 서비스 자동 배포
- ✅ Auto Scaling (CPU 기반)
- ✅ 헬스체크 및 Circuit Breaker
- ✅ CloudWatch Logs 통합
- ✅ 보안 그룹 자동 구성

## 사전 요구사항

1. **VPC 및 서브넷**
   - VPC ID
   - Private 서브넷 (최소 2개, Multi-AZ)
   - Public 서브넷 (최소 2개, Multi-AZ)

2. **서브넷 태그**
   ```hcl
   # Private 서브넷
   tags = {
     Type = "private"
   }

   # Public 서브넷
   tags = {
     Type = "public"
   }
   ```

3. **ACM 인증서** (HTTPS 사용 시, 선택사항)
   - HTTPS를 사용하려면 ACM 인증서 ARN 필요
   - 인증서가 없으면 HTTP만 사용 가능

## 사용 방법

### 1. terraform.tfvars 파일 생성

```hcl
# terraform.tfvars
aws_region   = "ap-northeast-2"
environment  = "dev"
service_name = "my-web-app"
vpc_id       = "vpc-xxxxxxxxxxxxx"

# 컨테이너 설정
container_image = "nginx:latest"
container_port  = 80

# Task 리소스
task_cpu    = 256
task_memory = 512

# 서비스 설정
desired_count = 2

# Auto Scaling
enable_autoscaling       = true
autoscaling_min_capacity = 2
autoscaling_max_capacity = 10
autoscaling_target_cpu   = 70

# HTTPS 사용 시 (선택사항)
certificate_arn = "arn:aws:acm:ap-northeast-2:123456789012:certificate/xxxxx"

# 환경 변수 (선택사항)
environment_variables = [
  {
    name  = "APP_ENV"
    value = "production"
  },
  {
    name  = "LOG_LEVEL"
    value = "info"
  }
]
```

### 2. Terraform 초기화 및 배포

```bash
# Terraform 초기화
terraform init

# 실행 계획 확인
terraform plan

# 리소스 배포
terraform apply
```

### 3. 배포 확인

```bash
# 출력 확인
terraform output

# 애플리케이션 접속
curl $(terraform output -raw application_url)
```

## 출력 값

| 출력 이름 | 설명 |
|----------|------|
| `alb_dns_name` | ALB의 DNS 이름 |
| `application_url` | 애플리케이션 접속 URL |
| `ecs_service_name` | ECS 서비스 이름 |
| `cloudwatch_log_group_name` | CloudWatch Log Group 이름 |

전체 출력 목록은 [outputs.tf](./outputs.tf)를 참조하세요.

## 리소스 목록

이 예제는 다음 AWS 리소스를 생성합니다:

- **네트워크**
  - Application Load Balancer
  - ALB Target Group
  - ALB Listeners (HTTP, HTTPS)
  - Security Groups (ALB, ECS Tasks)

- **컴퓨팅**
  - ECS Cluster
  - ECS Service (via module)
  - ECS Task Definition (via module)

- **IAM**
  - ECS Task Execution Role
  - ECS Task Role

- **모니터링**
  - CloudWatch Log Group (via module)
  - Auto Scaling Policies (via module)

## 비용 예상

### 월 예상 비용 (서울 리전 기준)

- **ECS Fargate** (256 CPU, 512 MB, 2 tasks, 24/7)
  - 약 $15/월

- **Application Load Balancer**
  - 약 $20/월

- **Data Transfer** (예상 50GB/월)
  - 약 $5/월

- **CloudWatch Logs** (5GB/월, 7일 보관)
  - 약 $3/월

**총 예상 비용: 약 $43/월**

> 실제 비용은 사용량에 따라 달라질 수 있습니다.

## 주요 설정 설명

### Auto Scaling

Auto Scaling은 CPU 사용률을 기반으로 자동으로 Task 수를 조정합니다:

```hcl
enable_autoscaling       = true
autoscaling_min_capacity = 2    # 최소 2개 Task
autoscaling_max_capacity = 10   # 최대 10개 Task
autoscaling_target_cpu   = 70   # CPU 70% 목표
```

### 헬스체크

ALB와 ECS 모두 헬스체크를 수행합니다:

- **ALB 헬스체크**: `/health` 경로로 HTTP 200 응답 확인
- **컨테이너 헬스체크**: 컨테이너 내부에서 curl로 확인

### Circuit Breaker

배포 실패 시 자동으로 이전 버전으로 롤백:

```hcl
deployment_circuit_breaker_enable   = true
deployment_circuit_breaker_rollback = true
```

## 커스터마이징

### 다른 컨테이너 이미지 사용

```hcl
container_image = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/my-app:latest"
container_port  = 8080
```

### 더 많은 리소스 할당

```hcl
task_cpu    = 512
task_memory = 1024
```

### ECS Exec 활성화 (디버깅용)

```hcl
enable_ecs_exec = true
```

사용 방법:
```bash
aws ecs execute-command \
  --cluster my-web-app-dev \
  --task <task-id> \
  --container my-web-app \
  --interactive \
  --command "/bin/sh"
```

## 보안 고려사항

1. **보안 그룹**
   - ALB: 인터넷(0.0.0.0/0)에서 80, 443 포트 허용
   - ECS Tasks: ALB에서만 컨테이너 포트 허용

2. **네트워크**
   - ECS Tasks는 Private 서브넷에 배포
   - ALB는 Public 서브넷에 배포

3. **HTTPS**
   - 운영 환경에서는 반드시 HTTPS 사용 권장
   - ACM 무료 인증서 활용 가능

## 모니터링

### CloudWatch Logs 확인

```bash
# Log Group 이름 확인
terraform output cloudwatch_log_group_name

# AWS CLI로 로그 확인
aws logs tail /ecs/my-web-app-dev --follow
```

### CloudWatch 메트릭 확인

- ECS → Clusters → [클러스터 이름] → Metrics
- CPU, Memory, Task 수 등 확인 가능

## 트러블슈팅

### Task가 시작되지 않음

1. **서브넷 태그 확인**
   ```bash
   aws ec2 describe-subnets --subnet-ids subnet-xxx --query 'Subnets[0].Tags'
   ```

2. **NAT Gateway 확인**
   - Private 서브넷에서 인터넷 접근 가능한지 확인

3. **IAM 역할 확인**
   - Task Execution Role에 ECR, CloudWatch Logs 권한 있는지 확인

### 헬스체크 실패

1. **헬스체크 경로 확인**
   ```bash
   # 컨테이너에서 헬스체크 경로 테스트
   curl http://localhost:80/health
   ```

2. **헬스체크 대기 시간 증가**
   ```hcl
   health_check_start_period = 120  # 기본 60초에서 120초로 증가
   ```

### ALB 접속 불가

1. **보안 그룹 확인**
   ```bash
   aws ec2 describe-security-groups --group-ids sg-xxx
   ```

2. **Target Group 상태 확인**
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output -raw target_group_arn)
   ```

## 정리

리소스를 삭제하려면:

```bash
terraform destroy
```

## 관련 문서

- [ECS Service 모듈 README](../../README.md)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [AWS Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)

## 라이선스

Internal use only - Infrastructure Team
