# ECS Task Execution Role Example

이 예시는 ECS가 컨테이너를 시작할 때 사용하는 Execution Role을 생성합니다.

## 포함된 권한

- **ECR Access**: Docker 이미지 풀링
- **CloudWatch Logs**: 컨테이너 로그 작성
- **Secrets Manager**: 환경 변수 주입용 시크릿 읽기
- **KMS**: 암호화된 이미지 및 로그 복호화

## Task Role과의 차이점

| Role Type | 사용 시점 | 주요 권한 |
|-----------|----------|----------|
| **Execution Role** | 컨테이너 시작 시 | ECR, CloudWatch Logs, Secrets 읽기 |
| **Task Role** | 컨테이너 런타임 | 애플리케이션이 필요한 AWS 서비스 |

## 사용 방법

```bash
# Initialize and apply
terraform init
terraform plan
terraform apply

# Get the role ARN
terraform output execution_role_arn
```

## ECS Task Definition에서 사용

```json
{
  "family": "example-app",
  "executionRoleArn": "arn:aws:iam::123456789012:role/example-ecs-task-execution-role",
  "taskRoleArn": "arn:aws:iam::123456789012:role/example-ecs-task-role",
  "containerDefinitions": [
    {
      "name": "app",
      "image": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/example-app:latest",
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/example-app",
          "awslogs-region": "ap-northeast-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "secrets": [
        {
          "name": "API_KEY",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:example/app/config-abc123:api_key::"
        }
      ]
    }
  ]
}
```

## 보안 고려사항

- ECR 이미지는 특정 리포지토리만 지정
- Secrets Manager는 컨테이너 시작에 필요한 것만 포함
- KMS 키 권한 최소화
- CloudWatch Logs 그룹 미리 생성 권장
