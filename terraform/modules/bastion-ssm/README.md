# Bastion Host with SSM Session Manager Module

Terraform 모듈로 AWS Systems Manager Session Manager를 사용하는 보안 바스티온 호스트를 배포합니다.

## 특징

- 🔐 **SSM Session Manager 접근**: SSH 키 없이 안전한 접근
- 🛡️ **향상된 보안**: Private subnet 배치, IMDSv2 강제, 키페어 불필요
- 📝 **세션 로깅**: CloudWatch Logs를 통한 모든 세션 기록
- 🔄 **자동 업데이트**: Amazon Linux 2023 최신 AMI 사용
- 🏷️ **거버넌스 준수**: Required tags 패턴 적용

## 사용 방법

### 기본 사용

```hcl
module "bastion" {
  source = "../../modules/bastion-ssm"

  environment = "prod"
  vpc_id      = aws_vpc.main.id
  vpc_cidr    = "10.0.0.0/16"
  subnet_id   = aws_subnet.private[0].id
  aws_region  = "ap-northeast-2"

  # Private subnet IDs for VPC endpoints
  private_subnet_ids = aws_subnet.private[*].id

  # Common tags (required for governance)
  common_tags = {
    Owner       = "platform-team"
    CostCenter  = "infrastructure"
    Environment = "prod"
    Lifecycle   = "production"
    DataClass   = "internal"
    Service     = "network"
  }
}
```

### 고급 설정

```hcl
module "bastion" {
  source = "../../modules/bastion-ssm"

  # Required
  environment        = "prod"
  vpc_id             = aws_vpc.main.id
  vpc_cidr           = "10.0.0.0/16"
  subnet_id          = aws_subnet.private[0].id
  aws_region         = "ap-northeast-2"
  private_subnet_ids = aws_subnet.private[*].id
  common_tags        = local.required_tags

  # Optional
  instance_type                = "t3.nano"
  volume_size                  = 20
  enable_session_logging       = true
  session_log_retention_days   = 30
  enable_detailed_monitoring   = true
}
```

## 접근 방법

### 1. AWS CLI 사용

```bash
# 인스턴스 ID 확인
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=prod-bastion" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
  --output table

# SSM Session 시작
aws ssm start-session --target <instance-id>
```

### 2. AWS Console 사용

1. AWS Systems Manager 콘솔로 이동
2. Session Manager 선택
3. Start Session 클릭
4. 바스티온 인스턴스 선택

## 필수 VPC 엔드포인트

이 모듈은 다음 VPC 엔드포인트를 자동으로 생성합니다:

- `com.amazonaws.{region}.ssm` - Systems Manager
- `com.amazonaws.{region}.ssmmessages` - Session Manager 메시지
- `com.amazonaws.{region}.ec2messages` - EC2 메시지
- `com.amazonaws.{region}.logs` (선택적) - CloudWatch Logs

## 보안 고려사항

- ✅ Private subnet에 배치 (public IP 없음)
- ✅ SSH 키페어 불필요
- ✅ IMDSv2 강제 (metadata v1 비활성화)
- ✅ 모든 세션 CloudWatch에 로깅
- ✅ EBS 볼륨 암호화
- ✅ 보안 그룹: egress만 허용 (ingress 없음)

## 요구사항

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | 환경 이름 (e.g., prod, staging, dev) | `string` | - | yes |
| vpc_id | VPC ID | `string` | - | yes |
| vpc_cidr | VPC CIDR 블록 | `string` | - | yes |
| subnet_id | 바스티온 인스턴스 subnet ID (private 권장) | `string` | - | yes |
| aws_region | AWS 리전 | `string` | - | yes |
| private_subnet_ids | VPC 엔드포인트용 private subnet ID 목록 | `list(string)` | - | yes |
| common_tags | 모든 리소스에 적용할 공통 태그 | `map(string)` | - | yes |
| instance_type | EC2 인스턴스 타입 | `string` | `"t3.nano"` | no |
| volume_size | 루트 볼륨 크기 (GB) | `number` | `20` | no |
| enable_session_logging | CloudWatch 세션 로깅 활성화 | `bool` | `true` | no |
| session_log_retention_days | 세션 로그 보관 기간 (일) | `number` | `30` | no |
| enable_detailed_monitoring | 상세 CloudWatch 모니터링 활성화 | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | 바스티온 EC2 인스턴스 ID |
| instance_arn | 바스티온 EC2 인스턴스 ARN |
| private_ip | 바스티온 인스턴스 private IP |
| security_group_id | 바스티온 보안 그룹 ID |
| iam_role_arn | 바스티온 IAM 역할 ARN |
| iam_role_name | 바스티온 IAM 역할 이름 |
| vpc_endpoints | VPC 엔드포인트 ID 맵 |
| session_log_group_name | CloudWatch 로그 그룹 이름 |
| ssm_document_name | SSM 문서 이름 |

## 비용 최적화

- **인스턴스 타입**: t3.nano (월 ~$3.80) 또는 t3.micro (월 ~$7.59)
- **VPC 엔드포인트**: Interface 엔드포인트당 ~$7.30/월
- **데이터 전송**: 처리된 데이터 GB당 ~$0.01
- **CloudWatch Logs**: 로그 수집 및 저장 비용

**추정 월 비용**: ~$30-40 (t3.nano + VPC 엔드포인트)

## 라이선스

이 모듈은 프로젝트 내부용입니다.
