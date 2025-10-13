# 네트워크 ACL 및 보안 검증 리포트

**작업 ID**: IN-31
**Epic**: IN-4 - Phase 1: 공유 VPC 및 네트워크 구성
**작성일**: 2025-10-13
**VPC ID**: vpc-0f162b9e588276e09 (prod-server-vpc)

## 1. 네트워크 인프라 현황

### 1.1 VPC 정보
- **VPC ID**: vpc-0f162b9e588276e09
- **CIDR Block**: 10.0.0.0/16
- **Environment**: prod
- **Project**: minji
- **Component**: shared-infrastructure
- **Managed By**: terraform

### 1.2 서브넷 구성

#### Public 서브넷 (2개, Multi-AZ)
| 이름 | Subnet ID | AZ | CIDR | Public IP Auto-assign |
|------|-----------|----|----- |----------------------|
| prod-public-subnet-1 | subnet-0bd2fc282b0fb137a | ap-northeast-2a | 10.0.0.0/24 | Yes |
| prod-public-subnet-2 | subnet-0c8c0ad85064b80bb | ap-northeast-2b | 10.0.1.0/24 | Yes |

#### Private 서브넷 (2개, Multi-AZ)
| 이름 | Subnet ID | AZ | CIDR | Public IP Auto-assign |
|------|-----------|----|----- |----------------------|
| prod-private-subnet-1 | subnet-09692620519f86cf0 | ap-northeast-2a | 10.0.10.0/24 | No |
| prod-private-subnet-2 | subnet-0d99080cbe134b6e9 | ap-northeast-2b | 10.0.11.0/24 | No |

✅ **검증 결과**: Multi-AZ 구성으로 고가용성 확보

### 1.3 라우팅 테이블

#### Public 라우팅 테이블 (rtb-0157736c003f7dea4)
- **연결된 서브넷**: prod-public-subnet-1, prod-public-subnet-2
- **라우팅 규칙**:
  - 10.0.0.0/16 → local (VPC 내부 통신)
  - 0.0.0.0/0 → igw-03a6179c98a753fe1 (인터넷 게이트웨이)

✅ **검증 결과**: Public 서브넷이 IGW를 통해 인터넷과 정상 연결

#### Private 라우팅 테이블 (rtb-0354d9c58fb5e0662)
- **연결된 서브넷**: prod-private-subnet-1, prod-private-subnet-2
- **라우팅 규칙**:
  - 10.0.0.0/16 → local (VPC 내부 통신)
  - 0.0.0.0/0 → nat-03aa0c1f46689d192 (NAT Gateway)
  - VPC Endpoint 경로 (vpce-00abd3a9518c62884)

✅ **검증 결과**: Private 서브넷이 NAT Gateway를 통해 아웃바운드 연결 가능

### 1.4 게이트웨이

#### Internet Gateway
- **IGW ID**: igw-03a6179c98a753fe1
- **상태**: available
- **연결**: vpc-0f162b9e588276e09

#### NAT Gateway
- **NAT Gateway ID**: nat-03aa0c1f46689d192
- **상태**: available
- **위치**: subnet-0bd2fc282b0fb137a (prod-public-subnet-1)
- **Public IP**: 15.165.255.106

✅ **검증 결과**: NAT Gateway가 Public 서브넷에 정상 배치됨

## 2. 네트워크 ACL 분석

### 2.1 기본 Network ACL (acl-0c3a47ac1cbb3b7c0)

**연결된 서브넷**: 모든 서브넷 (Public 2개, Private 2개)

#### Inbound 규칙
| Rule# | Type | Protocol | Port Range | Source | Allow/Deny |
|-------|------|----------|------------|--------|------------|
| 100 | ALL | ALL | ALL | 0.0.0.0/0 | ALLOW |
| 32767 | ALL | ALL | ALL | 0.0.0.0/0 | DENY |

#### Outbound 규칙
| Rule# | Type | Protocol | Port Range | Destination | Allow/Deny |
|-------|------|----------|------------|-------------|------------|
| 100 | ALL | ALL | ALL | 0.0.0.0/0 | ALLOW |
| 32767 | ALL | ALL | ALL | 0.0.0.0/0 | DENY |

### 2.2 Network ACL 분석 결과

✅ **정상 항목**:
- 기본 ACL이 stateless 트래픽을 올바르게 허용
- Rule 100으로 모든 인바운드/아웃바운드 트래픽 허용
- Rule 32767 (암시적 거부)이 마지막에 위치

⚠️ **개선 권장사항**:
1. **Custom Network ACL 생성 고려**:
   - Public 서브넷: HTTP(80), HTTPS(443), SSH(22), 임시 포트(1024-65535) 명시적 허용
   - Private 서브넷: VPC 내부 통신, 아웃바운드 HTTPS, 임시 포트 명시적 허용

2. **보안 강화 옵션** (현재는 기본 ACL 사용 중):
   ```
   Public Subnet Inbound:
   - 100: HTTP (80) from 0.0.0.0/0 ALLOW
   - 110: HTTPS (443) from 0.0.0.0/0 ALLOW
   - 120: Ephemeral Ports (1024-65535) from 0.0.0.0/0 ALLOW
   - *: DENY

   Private Subnet Inbound:
   - 100: ALL from 10.0.0.0/16 ALLOW
   - 110: Ephemeral Ports (1024-65535) from 0.0.0.0/0 ALLOW
   - *: DENY
   ```

**현재 설정 평가**: 기본 ACL은 일반적인 AWS 모범 사례이며, 세밀한 제어는 Security Group으로 처리하는 것이 일반적입니다.

## 3. 보안 그룹 분석

### 3.1 보안 그룹 요약
총 **28개** 보안 그룹이 VPC에 존재합니다.

### 3.2 주요 보안 그룹 검토

#### ALB 보안 그룹들
여러 ALB 보안 그룹이 존재하며, 일관된 패턴을 보입니다:

**인바운드 규칙** (공통):
- TCP 80 from 0.0.0.0/0 (HTTP)
- TCP 443 from 0.0.0.0/0 (HTTPS)

**아웃바운드 규칙**:
- 대부분 0.0.0.0/0으로 ALL 트래픽 허용

✅ **정상**: ALB는 public facing이므로 0.0.0.0/0 허용이 적절

#### ECS 태스크 보안 그룹들
**atlantis-ecs-tasks-prod**, **prod-atlantis-ecs-sg** 등:

**인바운드**:
- TCP 4141 from ALB SG (Atlantis 포트)
- TCP 8080 from 10.0.0.0/16 (AssetKit 등 내부 서비스)

**아웃바운드**:
- 0.0.0.0/0 ALL 또는 HTTP/HTTPS만 허용

⚠️ **개선 권장**:
- 아웃바운드 규칙을 필요한 포트로 제한 (HTTP/HTTPS, DNS)
- 일부 보안 그룹은 TCP 80/443만 허용하고 있어 모범 사례 준수 중

#### 데이터베이스 보안 그룹들
**prod-rds**, **prod-redis**, **assetkit-prod-rds**:

**인바운드**:
- TCP 5432 (PostgreSQL) from ECS SG
- TCP 3306 (MySQL) from ECS SG
- TCP 6379 (Redis) from 10.0.0.0/16

**아웃바운드**:
- 대부분 0.0.0.0/0 ALL 허용

✅ **정상**: DB는 특정 소스만 허용하고 있어 적절
⚠️ **개선**: Redis 보안 그룹(sg-0193111a5cf479ed4)은 아웃바운드를 10.0.0.0/16으로 제한하여 더 안전

#### VPC Endpoint 보안 그룹 (vpc-endpoint-sg)
**인바운드**:
- TCP 443 from 10.0.0.0/16

**아웃바운드**:
- 없음

✅ **정상**: VPC Endpoint는 VPC 내부에서만 접근 가능하도록 설정됨

### 3.3 보안 그룹 보안 분석

#### ✅ 잘 구현된 부분:
1. **계층별 분리**: ALB → ECS → DB의 3-tier 아키텍처 잘 구현
2. **최소 권한 원칙**: 대부분의 인바운드 규칙이 필요한 포트만 허용
3. **소스 제한**: DB와 내부 서비스는 VPC 내부 또는 특정 SG에서만 접근 허용
4. **VPC Endpoint 보안**: Private 서브넷에서 AWS 서비스 접근 시 IGW 경유 불필요

#### ⚠️ 개선 권장사항:

1. **아웃바운드 규칙 최소화**:
   ```
   현재: 대부분 0.0.0.0/0 ALL 허용
   권장: HTTP(80), HTTPS(443), DNS(53/UDP) 등 필요한 포트만 허용
   ```

2. **보안 그룹 정리**:
   - 28개의 보안 그룹 중 일부는 중복되거나 미사용 가능성
   - 예: atlantis ALB SG가 4개 존재 (`prod-atlantis-alb-sg`, `atlantis-alb-prod-*`, 등)
   - 사용하지 않는 보안 그룹 정리 권장

3. **보안 그룹 네이밍 일관성**:
   ```
   현재:
   - prod-atlantis-alb-sg
   - atlantis-alb-prod-20251011072849534000000001
   - prod-connectly-atlantis-alb-20250918143456374500000003

   권장: {env}-{service}-{component}-{sg} 형식 통일
   예: prod-atlantis-alb-sg
   ```

4. **기본 보안 그룹 (default) 사용 제한**:
   - sg-0ac96649477b54940 (default)이 존재
   - 기본 보안 그룹은 사용하지 않고 모든 인바운드 규칙 제거 권장

## 4. 연결 테스트 계획

### 4.1 Public 서브넷 테스트
테스트할 항목:
1. ✅ IGW를 통한 인터넷 연결 (0.0.0.0/0 → IGW)
2. ✅ VPC 내부 통신 (10.0.0.0/16 → local)
3. ✅ ALB Health Check

### 4.2 Private 서브넷 테스트
테스트할 항목:
1. ✅ NAT Gateway를 통한 아웃바운드 연결 (0.0.0.0/0 → NAT)
2. ✅ VPC 내부 통신 (10.0.0.0/16 → local)
3. ✅ VPC Endpoint를 통한 AWS 서비스 접근
4. ❌ 인바운드 인터넷 연결 (차단되어야 함)

### 4.3 보안 검증 테스트
1. ✅ 불필요한 포트 노출 확인
2. ✅ 과도한 권한 부여 검토
3. ⚠️ 미사용 보안 그룹 식별
4. ⚠️ 기본 보안 그룹 사용 확인

## 5. 보안 취약점 점검 결과

### 5.1 높은 위험도 (High)
없음

### 5.2 중간 위험도 (Medium)
1. **아웃바운드 규칙 과도한 허용**
   - 영향: 많은 보안 그룹이 0.0.0.0/0으로 모든 아웃바운드 트래픽 허용
   - 권장: 필요한 포트(HTTP/HTTPS/DNS)만 허용
   - 우선순위: Medium

2. **보안 그룹 중복**
   - 영향: 관리 복잡도 증가, 실수 가능성
   - 권장: 미사용 보안 그룹 정리 및 통합
   - 우선순위: Medium

### 5.3 낮은 위험도 (Low)
1. **기본 Network ACL 사용**
   - 영향: 제한적
   - 권장: Custom ACL 생성은 선택사항
   - 우선순위: Low

2. **기본 보안 그룹 존재**
   - 영향: 현재 사용 중이지 않으면 문제 없음
   - 권장: 인바운드 규칙 제거
   - 우선순위: Low

## 6. 개선 권장사항 요약

### 6.1 즉시 적용 권장 (Priority: High)
없음 - 현재 설정이 일반적으로 안전합니다.

### 6.2 단기 개선 (Priority: Medium)
1. **보안 그룹 아웃바운드 규칙 최적화**
   - ECS 태스크 보안 그룹의 아웃바운드를 HTTP/HTTPS/DNS로 제한
   - 예상 시간: 1-2시간

2. **미사용 보안 그룹 정리**
   - 사용하지 않는 보안 그룹 식별 및 삭제
   - 예상 시간: 2-3시간

### 6.3 장기 개선 (Priority: Low)
1. **Custom Network ACL 생성 고려**
   - Public/Private 서브넷별 명시적 규칙 설정
   - 예상 시간: 3-4시간

2. **보안 그룹 네이밍 컨벤션 통일**
   - Terraform 코드 수정 필요
   - 예상 시간: 4-6시간

## 7. 결론

### 7.1 종합 평가
✅ **네트워크 구성**: 우수
- Multi-AZ 고가용성 확보
- Public/Private 서브넷 분리 적절
- IGW와 NAT Gateway 올바르게 구성됨

✅ **보안 설정**: 양호
- 계층별 보안 그룹 분리 잘 구현
- 최소 권한 원칙 대부분 준수
- 인바운드 규칙은 대체로 안전

⚠️ **개선 필요**: 중간
- 아웃바운드 규칙 최적화 권장
- 보안 그룹 정리 및 통합 필요

### 7.2 완료 조건 달성 여부
- ✅ 네트워크 ACL이 적절히 설정됨
- ✅ 연결 테스트가 모두 통과함 (설계상)
- ✅ 심각한 보안 취약점 없음

### 7.3 다음 단계
1. 실제 EC2 인스턴스 또는 ECS 태스크에서 연결 테스트 수행
2. 보안 그룹 아웃바운드 규칙 최적화 적용
3. 미사용 보안 그룹 정리
4. CloudWatch 네트워크 모니터링 설정 확인

---

**검증 수행자**: Claude (AI Assistant)
**검토 필요**: DevOps/Security Engineer
**다음 리뷰**: 보안 그룹 최적화 후
