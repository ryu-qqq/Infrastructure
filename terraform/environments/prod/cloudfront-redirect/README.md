# CloudFront Redirect - server.set-of.net → www.set-of.com

> ⚠️ **적용 전 확인**: 프론트엔드 팀에서 `www.set-of.net` → `www.set-of.com` 리다이렉트 완료 후 적용하세요!
>
> 📋 **운영 가이드**: [RUNBOOK.md](./RUNBOOK.md) 참조

이 모듈은 `server.set-of.net`으로 들어오는 모든 요청을 `www.set-of.com`으로 301 리다이렉트합니다.

## 아키텍처

```
┌─────────────────────────┐
│  server.set-of.net      │
└───────────┬─────────────┘
            ↓
┌─────────────────────────┐
│  Route53 (A/AAAA)       │
└───────────┬─────────────┘
            ↓
┌─────────────────────────┐
│  CloudFront Distribution │
│  + CloudFront Function   │  ← 301 Redirect 처리
│  (*.set-of.net 인증서)   │
└───────────┬─────────────┘
            ↓ 301 Redirect (경로 유지)
┌─────────────────────────┐
│  www.set-of.com         │
└─────────────────────────┘
```

## 리다이렉트 예시

| 요청 URL | 리다이렉트 URL |
|----------|----------------|
| `https://server.set-of.net/` | `https://www.set-of.com/` |
| `https://server.set-of.net/api/v1/users` | `https://www.set-of.com/api/v1/users` |
| `https://server.set-of.net/api/v1/auth?token=abc` | `https://www.set-of.com/api/v1/auth?token=abc` |

## 리소스

- **CloudFront Function**: `redirect-server-to-www`
  - Runtime: `cloudfront-js-2.0`
  - 모든 요청을 301 리다이렉트로 응답

- **CloudFront Distribution**: 리다이렉트 전용
  - Alias: `server.set-of.net`
  - 인증서: `*.set-of.net` (ACM, us-east-1)
  - Price Class: `PriceClass_200`

- **Route53 Records**: A/AAAA 레코드
  - `server.set-of.net` → CloudFront Distribution

## 사용 방법

```bash
cd terraform/environments/prod/cloudfront-redirect

# 초기화
terraform init

# 계획 확인
terraform plan

# 적용
terraform apply
```

## 주의사항

1. **기존 ALB 연결 해제**: 이 모듈을 적용하면 `server.set-of.net`이 기존 ALB 대신 CloudFront로 연결됩니다.

2. **인증서 요구사항**: `*.set-of.net` 와일드카드 인증서가 us-east-1 리전에 있어야 합니다.

3. **캐싱**: 301 리다이렉트 응답은 브라우저에서 캐싱됩니다 (`max-age=86400`).

## 롤백 절차

문제 발생 시 기존 ALB로 롤백:

```bash
# Route53 레코드만 되돌리기
terraform destroy -target=aws_route53_record.redirect -target=aws_route53_record.redirect_ipv6
```

그 후 AWS 콘솔에서 수동으로 기존 ALB 레코드 복원 또는:

```bash
aws route53 change-resource-record-sets --hosted-zone-id Z02584341WZ7FPIKF06FI --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "server.set-of.net",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "ZWKZPGTI48KDX",
        "DNSName": "dualstack.setof-web-server-lb-428831385.ap-northeast-2.elb.amazonaws.com",
        "EvaluateTargetHealth": true
      }
    }
  }]
}'
```
