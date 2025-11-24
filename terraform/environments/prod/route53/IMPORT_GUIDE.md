# Route53 Terraform Import Guide

기존에 AWS 콘솔에서 생성한 Route53 리소스를 Terraform으로 Import하는 가이드입니다.

## Prerequisites

1. AWS CLI 설치 및 구성
2. Terraform 1.5.0 이상 설치
3. 해당 AWS 계정에 대한 적절한 권한

## Step 1: 기존 리소스 정보 확인

### Hosted Zone ID 확인

```bash
# 모든 Hosted Zone 조회
aws route53 list-hosted-zones

# 특정 도메인의 Zone ID 확인
aws route53 list-hosted-zones | grep -A 3 "set-of.com"
```

출력 예시:
```json
{
  "Id": "/hostedzone/Z1234567890ABC",
  "Name": "set-of.com.",
  "CallerReference": "..."
}
```

**Zone ID**: `Z1234567890ABC` (실제 값으로 대체)

### 기존 DNS 레코드 확인

```bash
# Zone ID를 사용하여 모든 레코드 조회
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC

# 특정 레코드만 조회 (예: atlantis)
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC | grep -A 10 "atlantis"
```

## Step 2: Terraform 초기화

```bash
cd terraform/route53

# Terraform 초기화
terraform init

# 현재 상태 확인 (import 전에는 비어있음)
terraform state list
```

## Step 3: Hosted Zone Import

### Import 명령 실행

```bash
# Hosted Zone Import
terraform import aws_route53_zone.primary Z1234567890ABC
```

성공 출력:
```
aws_route53_zone.primary: Importing from ID "Z1234567890ABC"...
aws_route53_zone.primary: Import prepared!
aws_route53_zone.primary: Import complete!
```

### Import 검증

```bash
# State에 추가되었는지 확인
terraform state list

# 상세 정보 확인
terraform state show aws_route53_zone.primary

# Plan 실행 (변경사항이 없어야 함)
terraform plan
```

**Expected Output**: `No changes. Your infrastructure matches the configuration.`

만약 변경사항이 감지되면:
- 태그나 설정이 코드와 다른 경우 코드 수정
- `force_destroy`, `comment` 등의 값 조정

## Step 4: DNS 레코드 Import (선택사항)

기존 DNS 레코드들도 Terraform으로 관리하려면 각각 import 필요합니다.

### 레코드 리소스 정의 추가

`records.tf` 파일 생성:

```hcl
# atlantis A 레코드 (ALB alias)
resource "aws_route53_record" "atlantis" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "atlantis.set-of.com"
  type    = "A"

  alias {
    name                   = "alb-123456.ap-northeast-2.elb.amazonaws.com"
    zone_id                = "Z1234567890DEF"
    evaluate_target_health = true
  }
}
```

### 레코드 Import 명령

```bash
# 레코드 import 형식: terraform import <resource> <zone_id>_<record_name>_<record_type>
terraform import aws_route53_record.atlantis Z1234567890ABC_atlantis.set-of.com_A
```

### 여러 레코드 Import 스크립트

`import-records.sh` 생성:

```bash
#!/bin/bash

ZONE_ID="Z1234567890ABC"

# Import all existing records
terraform import aws_route53_record.atlantis "${ZONE_ID}_atlantis.set-of.com_A"
terraform import aws_route53_record.www "${ZONE_ID}_www.set-of.com_A"
terraform import aws_route53_record.api "${ZONE_ID}_api.set-of.com_A"

echo "Import completed. Run 'terraform plan' to verify."
```

실행:
```bash
chmod +x import-records.sh
./import-records.sh
```

## Step 5: Health Check Import (선택사항)

기존 Health Check가 있다면 import:

```bash
# Health Check ID 확인
aws route53 list-health-checks

# Import
terraform import aws_route53_health_check.atlantis <HEALTH_CHECK_ID>
```

## Step 6: Query Logging Import (선택사항)

기존 Query Logging 설정이 있다면:

```bash
# Query Log Config ID 확인
aws route53 list-query-logging-configs

# Import
terraform import aws_route53_query_log.primary <QUERY_LOG_CONFIG_ID>
```

## Step 7: 최종 검증

```bash
# 모든 리소스 확인
terraform state list

# Plan 실행 - 변경사항 없어야 함
terraform plan

# 출력 확인
terraform output
```

## Troubleshooting

### Import 실패: "resource not found"

**원인**: Zone ID 또는 리소스 ID가 잘못됨
**해결**: AWS CLI로 정확한 ID 확인 후 재시도

```bash
aws route53 list-hosted-zones
aws route53 list-health-checks
```

### Plan에서 변경사항 감지

**원인**: Terraform 코드와 실제 리소스 설정이 다름
**해결**:

1. `terraform state show` 명령으로 실제 값 확인
2. Terraform 코드의 값을 실제 값과 일치시킴
3. 특정 속성은 `lifecycle { ignore_changes }` 사용

예시:
```hcl
resource "aws_route53_zone" "primary" {
  # ... other config ...

  lifecycle {
    ignore_changes = [
      tags["LastModified"]  # AWS가 자동으로 추가하는 태그 무시
    ]
  }
}
```

### 태그 관련 차이

**원인**: AWS 콘솔에서 설정한 태그와 Terraform 코드의 태그 불일치
**해결**:

```bash
# 현재 태그 확인
terraform state show aws_route53_zone.primary | grep -A 10 tags

# locals.tf의 required_tags 업데이트하여 일치시킴
```

### Import 후 destroy 방지

```hcl
resource "aws_route53_zone" "primary" {
  # ... other config ...

  lifecycle {
    prevent_destroy = true  # 실수로 삭제 방지
  }
}
```

## Import 체크리스트

- [ ] AWS CLI로 Hosted Zone ID 확인
- [ ] Terraform 코드에 리소스 정의 작성
- [ ] `terraform init` 실행
- [ ] `terraform import` 명령으로 Hosted Zone import
- [ ] `terraform state list`로 import 확인
- [ ] `terraform plan`으로 변경사항 없음 확인
- [ ] 필요시 DNS 레코드들도 import
- [ ] Health Check import (있는 경우)
- [ ] Query Logging import (있는 경우)
- [ ] 최종 `terraform plan` 및 `terraform output` 확인
- [ ] 문서화 및 팀 공유

## 참고 자료

- [Terraform Import Documentation](https://developer.hashicorp.com/terraform/cli/import)
- [AWS Route53 Terraform Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone)
- [Route53 Import Guide (공식)](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-listing.html)
