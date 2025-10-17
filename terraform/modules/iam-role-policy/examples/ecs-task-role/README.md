# ECS Task Role Example

이 예시는 ECS 컨테이너가 런타임에 사용하는 Task Role을 생성합니다.

## 포함된 권한

- **ECS Task Policy**: ECS 작업 기본 권한
- **RDS Access**: 데이터베이스 클러스터 접근
- **Secrets Manager**: 시크릿 읽기 전용
- **S3 Access**: 특정 버킷/경로에 대한 읽기/쓰기
- **CloudWatch Logs**: 로그 작성
- **KMS**: 암호화된 리소스 복호화

## 사용 방법

```bash
# Initialize and apply
terraform init
terraform plan
terraform apply

# Get the role ARN
terraform output task_role_arn
```

## ECS Task Definition에서 사용

```json
{
  "family": "example-app",
  "taskRoleArn": "arn:aws:iam::123456789012:role/example-ecs-task-role",
  "containerDefinitions": [...]
}
```

## 보안 고려사항

- RDS IAM 인증 사용 권장
- Secrets Manager로 민감한 정보 관리
- S3 객체 경로를 최대한 구체적으로 제한
- KMS 암호화 사용
