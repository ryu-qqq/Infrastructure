# Complete Example

이 예제는 프로덕션 환경에서 사용 가능한 완전한 ECS 서비스 스택을 보여줍니다.

## 포함된 구성 요소

- VPC 및 네트워킹 (서브넷, NAT Gateway)
- ECS Cluster (Container Insights 활성화)
- Application Load Balancer
- Route 53 DNS 레코드
- ACM 인증서
- Auto Scaling 정책
- CloudWatch 알람
- WAF 규칙 (선택적)

## 추가 예정

이 예제는 IN-122 태스크의 일부로 추가 개발될 예정입니다.
실제 프로덕션 환경 배포를 위한 모든 모범 사례가 포함될 예정입니다.
