# Basic RDS Example

이 예제는 최소 설정으로 RDS MySQL 인스턴스를 배포하는 방법을 보여줍니다.

## 배포되는 리소스

- RDS MySQL 인스턴스 (db.t3.micro, 20GB 스토리지)
- DB 서브넷 그룹
- 보안 그룹

## 사용 방법

1. **변수 설정**

`terraform.tfvars` 파일을 생성하고 다음 내용을 입력합니다:

```hcl
vpc_id          = "vpc-xxxxx"
environment     = "dev"
service_name    = "myapp"
db_name         = "myappdb"
master_username = "dbadmin"
master_password = "YourSecurePassword123!"  # 실제로는 Secrets Manager 사용 권장
```

2. **초기화 및 배포**

```bash
terraform init
terraform plan
terraform apply
```

3. **출력 확인**

```bash
terraform output db_endpoint
terraform output db_address
```

## 특징

- ✅ 최소 필수 설정만 포함
- ✅ 개발 환경에 적합
- ✅ 기본 암호화 활성화
- ✅ 7일 자동 백업
- ✅ gp3 스토리지 사용

## 주의사항

- 프로덕션 환경에서는 [advanced 예제](../advanced/)를 참조하세요
- 마스터 비밀번호는 AWS Secrets Manager에 저장하는 것을 권장합니다
- 보안 그룹 규칙을 특정 애플리케이션 보안 그룹으로 제한하세요

## 예상 비용

db.t3.micro (Single-AZ, 20GB gp3):
- 인스턴스: ~$15/월
- 스토리지: ~$2/월
- 백업: 추가 비용 발생 가능

**총 예상 비용**: ~$17-20/월 (Seoul 리전 기준)

## 정리

```bash
terraform destroy
```

**주의**: 최종 스냅샷이 생성되므로 완전히 삭제하려면 AWS 콘솔에서 스냅샷도 삭제해야 합니다.
