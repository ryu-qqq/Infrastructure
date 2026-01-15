# Runbook: server.set-of.net 리다이렉트

## 개요

`server.set-of.net` → `www.set-of.com` 301 리다이렉트 설정

### 사전 조건

- [x] Terraform 코드 준비 완료
- [ ] **프론트엔드 팀에서 `www.set-of.net` → `www.set-of.com` 리다이렉트 완료**
- [ ] 적용 승인

---

## 적용 절차

### Step 1: 사전 확인

```bash
cd terraform/environments/prod/cloudfront-redirect

# 현재 Route53 상태 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id Z02584341WZ7FPIKF06FI \
  --query "ResourceRecordSets[?Name=='server.set-of.net.']"

# 현재 응답 확인
curl -I https://server.set-of.net/api/v1/health
```

### Step 2: Terraform Plan 확인

```bash
terraform plan
```

**예상 결과**: 4개 리소스 생성
- `aws_cloudfront_function.redirect`
- `aws_cloudfront_distribution.redirect`
- `aws_route53_record.redirect` (A)
- `aws_route53_record.redirect_ipv6` (AAAA)

### Step 3: Terraform Apply

```bash
terraform apply
```

**예상 소요 시간**: 약 5-10분 (CloudFront 배포)

### Step 4: 검증

```bash
./scripts/verify.sh
```

또는 수동 확인:

```bash
# DNS 확인
dig server.set-of.net

# 리다이렉트 확인
curl -I https://server.set-of.net/
curl -I https://server.set-of.net/api/v1/users

# 예상 결과:
# HTTP/2 301
# location: https://www.set-of.com/api/v1/users
```

---

## 롤백 절차

### 방법 1: 스크립트 사용 (권장)

```bash
./scripts/rollback.sh
```

### 방법 2: 수동 롤백

```bash
# Route53 A 레코드를 기존 ALB로 복원
aws route53 change-resource-record-sets \
  --hosted-zone-id Z02584341WZ7FPIKF06FI \
  --change-batch '{
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

### 방법 3: Terraform Destroy (Route53만)

```bash
terraform destroy \
  -target=aws_route53_record.redirect \
  -target=aws_route53_record.redirect_ipv6
```

그 후 수동으로 기존 ALB 레코드 복원 (방법 2 참조)

---

## 장애 대응

### 증상별 대응

| 증상 | 원인 | 대응 |
|------|------|------|
| 502 Bad Gateway | CloudFront 설정 오류 | 롤백 스크립트 실행 |
| CORS 에러 | 프론트 리다이렉트 미완료 | 롤백 후 프론트 팀 확인 |
| 리다이렉트 무한 루프 | Function 로직 오류 | 롤백 스크립트 실행 |
| SSL 인증서 오류 | ACM 인증서 문제 | 인증서 상태 확인 |

### 긴급 연락처

| 역할 | 담당 |
|------|------|
| 인프라 | (담당자 연락처) |
| 프론트엔드 | (담당자 연락처) |
| 백엔드 | (담당자 연락처) |

---

## 적용 후 정리 작업

리다이렉트 안정화 확인 후 (1-2주 모니터링):

1. **기존 ALB 삭제**: `setof-web-server-lb-428831385`
2. **기존 EC2 인스턴스 종료**
3. **관련 Security Group 정리**
4. **모니터링 알람 정리**

---

## 참고 정보

### 리소스 정보

| 항목 | 값 |
|------|-----|
| Route53 Zone ID | `Z02584341WZ7FPIKF06FI` |
| 기존 ALB DNS | `setof-web-server-lb-428831385.ap-northeast-2.elb.amazonaws.com` |
| 기존 ALB Zone ID | `ZWKZPGTI48KDX` |
| ACM 인증서 (*.set-of.net) | `arn:aws:acm:us-east-1:646886795421:certificate/783f28e4-b346-4502-807c-b62fe1293178` |

### Terraform State

```
s3://prod-connectly/environments/prod/cloudfront-redirect/terraform.tfstate
```
