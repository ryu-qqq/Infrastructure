# Atlantis IAM Configuration (Archived)

## 상태 (Status)

⚠️ **이 디렉토리는 더 이상 활발히 사용되지 않습니다.**

이 디렉토리는 Atlantis 서버를 위한 IAM 역할 및 정책 구성을 관리했던 영역입니다. 현재는 Terraform state 파일들만 남아있으며, Terraform 코드 파일들(.tf)은 존재하지 않습니다.

## 히스토리 (History)

- Atlantis 서버가 AWS 리소스에 접근하기 위한 IAM 역할 생성
- 필요한 IAM 정책 및 권한 구성
- State 파일을 통해 리소스 상태 추적

## State 파일 (State Files)

다음 파일들이 존재합니다:
- `terraform.tfstate` - 현재 상태
- `terraform.tfstate.*.backup` - 백업 파일들

⚠️ **중요**: 이 state 파일들은 AWS에 생성된 실제 리소스를 추적하고 있습니다.
삭제하기 전에 반드시 다음을 확인하세요:
1. State에 관리되는 리소스가 여전히 사용 중인지
2. 리소스를 삭제해야 하는지, 아니면 다른 Terraform 구성으로 import해야 하는지

## 권장 조치 (Recommended Actions)

### 옵션 1: State 관리 이전
만약 이 리소스들이 여전히 사용 중이라면:
```bash
# State 내용 확인
terraform state list

# 다른 구성으로 이동
terraform state mv <resource> <destination>
```

### 옵션 2: 리소스 정리
만약 더 이상 필요하지 않다면:
```bash
# State에서 리소스 제거 (AWS 리소스는 유지)
terraform state rm <resource>

# 또는 실제 리소스도 삭제
terraform destroy
```

### 옵션 3: 아카이브
State만 보관하고 디렉토리를 아카이브:
```bash
# 디렉토리를 archived/ 하위로 이동
mkdir -p ../archived
mv terraform/atlantis-iam ../archived/
```

## 참고 문서 (References)

- [Terraform State 관리](https://developer.hashicorp.com/terraform/language/state)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Atlantis 문서](../atlantis/README.md)

## 문의 (Contact)

- **Epic**: [IN-1 - Phase 1: Atlantis 서버 ECS 배포](https://ryuqqq.atlassian.net/browse/IN-1)
- **관련 문서**: Infrastructure Team
