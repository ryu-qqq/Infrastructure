# Route53 Hosted Zone Template

새로운 Route53 Hosted Zone 생성을 위한 재사용 가능한 Terraform 템플릿입니다.

## 📋 개요

- **Hosted Zone 생성**: 도메인 DNS 관리
- **Name Server 출력**: 도메인 등록 업체에 설정할 NS 레코드
- **SSM Parameter 생성**: Cross-stack 참조용

## 🚀 빠른 시작

```bash
cd terraform/your-project/route53/

# 1. terraform.tfvars 수정
vi terraform.tfvars

# 2. Hosted Zone 생성
terraform init
terraform plan
terraform apply
```

## 📝 사용 예제

```hcl
domain_name = "example.com"
```

## 🔄 다른 프로젝트에서 참조

```hcl
data "aws_ssm_parameter" "zone_id" {
  name = "/shared/my-project/dns/example-com/zone-id"
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_ssm_parameter.zone_id.value
  name    = "www.example.com"
  type    = "A"
  ttl     = 300
  records = ["192.0.2.1"]
}
```

## ⚠️ 주의사항

- **Name Server 설정**: 생성 후 도메인 등록 업체에 Name Server 설정 필요
- **전파 시간**: DNS 전파에 최대 48시간 소요
- **force_destroy**: 프로덕션에서는 `false` 권장

---

**템플릿 버전**: 1.0.0
**최종 업데이트**: 2025-11-21
