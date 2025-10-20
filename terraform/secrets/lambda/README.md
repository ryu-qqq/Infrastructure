# RDS Secrets Manager Rotation Lambda

AWS Secrets Manager의 자동 로테이션 기능을 사용하여 RDS MySQL 마스터 비밀번호를 주기적으로 자동 교체하는 Lambda 함수입니다.

## 개요

이 Lambda 함수는 AWS Secrets Manager의 4단계 로테이션 프로세스를 구현합니다:

1. **createSecret**: 새로운 비밀번호 생성
2. **setSecret**: RDS에서 비밀번호 업데이트
3. **testSecret**: 새 비밀번호로 연결 테스트
4. **finishSecret**: 로테이션 완료 및 버전 전환

## 아키텍처

```
┌─────────────────────┐      ┌──────────────────────┐
│ Secrets Manager     │─────▶│ Rotation Lambda      │
│ - RDS Credentials   │      │ - VPC                │
│ - 30일 자동 로테이션  │      │ - Security Group     │
└─────────────────────┘      └──────────────────────┘
                                      │
                                      ▼
                              ┌──────────────────────┐
                              │ RDS MySQL            │
                              │ - Master Password    │
                              │ - ALTER USER         │
                              └──────────────────────┘
```

## 파일 구조

```
terraform/secrets/lambda/
├── index.py            # Lambda 함수 코드 (Python)
├── requirements.txt    # Python 의존성 (pymysql)
├── build.sh           # 배포 패키지 빌드 스크립트
├── rotation.zip       # 배포 패키지 (자동 생성)
└── README.md          # 이 문서
```

## 빌드 방법

Lambda 배포 패키지를 빌드하려면:

```bash
cd terraform/secrets/lambda
./build.sh
```

빌드 스크립트는 다음을 수행합니다:
1. Python 의존성 설치 (`requirements.txt`)
2. Lambda 함수 코드 복사
3. ZIP 파일 생성 (`rotation.zip`)

## 배포

### Terraform을 통한 배포

```bash
cd terraform/secrets
terraform init
terraform plan
terraform apply
```

### 필요한 리소스

- **VPC 설정**: Lambda가 RDS에 접근하기 위해 VPC 내에서 실행됩니다
- **보안 그룹**: Lambda → RDS MySQL (3306 포트) 통신 허용
- **IAM Role**: Secrets Manager, RDS, KMS 접근 권한
- **KMS Key**: Secrets Manager 암호화용

## 로테이션 설정

### 자동 로테이션 주기

기본값: **30일**

변경하려면 `terraform/rds/terraform.auto.tfvars`에서:

```hcl
rotation_days = 30  # 1-365일 사이 값
```

### 수동 로테이션 트리거

AWS CLI로 수동 로테이션 실행:

```bash
aws secretsmanager rotate-secret \
  --secret-id prod-shared-mysql-master-password \
  --region ap-northeast-2
```

## 모니터링

### CloudWatch 알람

1. **Rotation Failures** (심각도: HIGH)
   - Lambda 실행 실패 시 즉시 알림
   - 보안 컴플라이언스에 영향
   - Runbook: [Secrets Rotation Troubleshooting](https://github.com/ryu-qqq/Infrastructure/wiki/Secrets-Rotation-Runbook)

2. **Rotation Duration** (심각도: MEDIUM)
   - 로테이션이 50초 이상 소요 시 알림
   - DB 성능 이슈 가능성

### CloudWatch Logs

Lambda 실행 로그:
```bash
aws logs tail /aws/lambda/secrets-manager-rotation --follow
```

## 트러블슈팅

### 로테이션 실패 시

1. **Lambda 로그 확인**
   ```bash
   aws logs tail /aws/lambda/secrets-manager-rotation --since 1h
   ```

2. **보안 그룹 확인**
   - Lambda 보안 그룹이 RDS 보안 그룹에서 3306 포트 허용하는지 확인

3. **IAM 권한 확인**
   - Secrets Manager 읽기/쓰기 권한
   - RDS DescribeDBInstances, ModifyDBInstance 권한
   - KMS Decrypt, GenerateDataKey 권한

4. **RDS 연결 확인**
   - RDS 인스턴스가 실행 중인지 확인
   - VPC 및 서브넷 설정 확인

### 일반적인 문제

| 문제 | 원인 | 해결 방법 |
|------|------|----------|
| Connection timeout | Lambda가 RDS에 도달 불가 | VPC/보안 그룹 확인 |
| Access denied | IAM 권한 부족 | IAM 정책 검토 |
| ALTER USER failed | MySQL 권한 부족 | Master user 권한 확인 |
| KMS error | KMS 키 접근 불가 | KMS 정책 확인 |

## 보안 고려사항

1. **최소 권한 원칙**
   - Lambda IAM Role은 필요한 최소 권한만 부여
   - KMS 키 정책으로 암호화 키 접근 제한

2. **네트워크 격리**
   - Lambda는 Private Subnet에서만 실행
   - RDS는 Public Subnet 접근 불가

3. **감사 로그**
   - 모든 로테이션 이벤트는 CloudWatch Logs에 기록
   - CloudTrail로 API 호출 감사

4. **롤백 전략**
   - Secrets Manager는 이전 버전 자동 보관
   - 로테이션 실패 시 이전 버전으로 즉시 전환 가능

## 운영 가이드

### 초기 설정

1. Secrets Manager 스택 배포
   ```bash
   cd terraform/secrets
   terraform apply
   ```

2. RDS 스택에서 로테이션 활성화
   ```bash
   cd terraform/rds
   # terraform.auto.tfvars에서 enable_secrets_rotation = true 확인
   terraform apply
   ```

3. 첫 로테이션 수동 테스트 (권장: 비운영 시간대)
   ```bash
   aws secretsmanager rotate-secret \
     --secret-id prod-shared-mysql-master-password \
     --region ap-northeast-2
   ```

### 정기 점검

- **월 1회**: CloudWatch 알람 및 메트릭 검토
- **분기 1회**: 로테이션 로그 분석 및 성공률 검토
- **반기 1회**: IAM 정책 및 보안 그룹 검토

### 비상 연락처

- **보안 이슈**: security@ryuqqq.com
- **인프라 이슈**: platform-team@ryuqqq.com
- **온콜**: PagerDuty 알림 확인

## 참고 자료

- [AWS Secrets Manager Rotation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)
- [RDS Password Rotation Lambda Samples](https://github.com/aws-samples/aws-secrets-manager-rotation-lambdas)
- [Terraform AWS Secrets Manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_rotation)
- [Internal Runbook](https://github.com/ryu-qqq/Infrastructure/wiki/Secrets-Rotation-Runbook)

## 라이선스

Internal use only - ryuqqq Infrastructure Team
