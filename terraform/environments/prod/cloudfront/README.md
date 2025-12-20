# CloudFront CDN Stack

cdn.set-of.com을 위한 CloudFront 배포 관리

## 개요

다중 S3 오리진을 사용하는 CloudFront 배포:

| 경로 패턴 | S3 버킷 | 용도 |
|-----------|---------|------|
| `/otel-config/*` | prod-connectly | OTEL 설정 파일 |
| `/uploads/*` | fileflow-uploads-prod | 파일 업로드 |
| `/*` (기본) | connectly-prod | 레거시 (향후 마이그레이션) |

## URL 예시

```
https://cdn.set-of.com/otel-config/authhub-web-api/otel-config.yaml
https://cdn.set-of.com/uploads/images/photo.jpg
https://cdn.set-of.com/some-legacy-file.txt
```

## Import 방법

기존 CloudFront 배포를 Terraform으로 가져오기:

```bash
cd terraform/environments/prod/cloudfront

# 1. Init
terraform init

# 2. Import existing CloudFront distribution
terraform import aws_cloudfront_distribution.cdn E1CMSWVL5HVMGH

# 3. Plan & Apply
terraform plan
terraform apply
```

## 새 오리진 추가 방법

1. `locals.tf`의 `origins` 블록에 새 오리진 추가
2. `main.tf`에 origin 블록 추가
3. `main.tf`에 ordered_cache_behavior 블록 추가
4. 해당 S3 버킷의 정책 추가

## 캐시 무효화

```bash
aws cloudfront create-invalidation \
  --distribution-id E1CMSWVL5HVMGH \
  --paths "/otel-config/*"
```
