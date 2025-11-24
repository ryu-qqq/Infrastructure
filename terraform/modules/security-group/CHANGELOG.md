# Changelog

All notable changes to the security-group module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-23

### Added

#### Core Features
- **타입 기반 Security Group 템플릿 시스템**
  - ALB 타입: HTTP/HTTPS ingress 규칙 자동 구성
  - ECS 타입: ALB로부터 컨테이너 포트 ingress 규칙
  - RDS 타입: ECS로부터 데이터베이스 포트 ingress 규칙
  - VPC Endpoint 타입: VPC 내부 접근 제어
  - Custom 타입: 완전한 커스텀 규칙 지원

#### Security Group Rules
- **ALB 전용 규칙**
  - HTTP/HTTPS 포트 개별 활성화/비활성화 (`alb_enable_http`, `alb_enable_https`)
  - 커스터마이징 가능한 HTTP/HTTPS 포트 번호
  - CIDR 기반 ingress 제어

- **ECS 전용 규칙**
  - ALB Security Group 참조를 통한 트래픽 허용
  - 컨테이너 포트 설정
  - 추가 Security Group 허용 목록 지원

- **RDS 전용 규칙**
  - ECS Security Group 참조를 통한 DB 접근 제어
  - 데이터베이스 포트 설정 (기본값: 5432 PostgreSQL)
  - 추가 Security Group 허용 목록 지원
  - CIDR 기반 접근 제어 (선택적)

- **VPC Endpoint 전용 규칙**
  - CIDR 블록 기반 접근 제어
  - Security Group 참조 기반 접근 제어
  - 커스터마이징 가능한 엔드포인트 포트 (기본값: 443)

#### Custom Rules
- **유연한 커스텀 Ingress 규칙**
  - IPv4 CIDR 블록 지원 (`cidr_block`)
  - IPv6 CIDR 블록 지원 (`ipv6_cidr_block`)
  - Security Group 참조 지원 (`source_security_group_id`)
  - 포트 범위 설정 (`from_port`, `to_port`)
  - 프로토콜 지정 (`protocol`)
  - 규칙별 설명 (`description`)

- **유연한 커스텀 Egress 규칙**
  - IPv4 CIDR 블록 지원 (`cidr_block`)
  - IPv6 CIDR 블록 지원 (`ipv6_cidr_block`)
  - Security Group 참조 지원 (`destination_security_group_id`)
  - 포트 범위 설정 (`from_port`, `to_port`)
  - 프로토콜 지정 (`protocol`)
  - 규칙별 설명 (`description`)

#### Lifecycle Management
- **안전한 리소스 교체**
  - `create_before_destroy = true` 적용
  - 무중단 Security Group 업데이트 지원

- **규칙 삭제 관리**
  - `revoke_rules_on_delete` 옵션 (기본값: false)
  - 삭제 시 모든 규칙 먼저 제거 옵션

#### Tagging System
- **common-tags 모듈 통합**
  - 필수 태그 자동 적용 (Environment, Service, Team, Owner, CostCenter)
  - 선택적 태그 (Project, DataClass)
  - 추가 태그 병합 지원 (`additional_tags`)

- **모듈 자체 태그**
  - Name: Security Group 이름
  - Description: Security Group 설명
  - Type: Security Group 타입 (alb, ecs, rds, vpc-endpoint, custom)

#### Validation Rules
- **이름 규칙 검증**
  - Security Group name: kebab-case, 최대 255자
  - Service name: kebab-case
  - Team: kebab-case
  - Cost center: kebab-case
  - Project: kebab-case

- **환경 검증**
  - Environment: dev, staging, prod 중 하나

- **데이터 분류 검증**
  - Data class: confidential, internal, public 중 하나

- **타입 검증**
  - Type: alb, ecs, rds, vpc-endpoint, custom 중 하나

- **커스텀 규칙 검증**
  - 각 규칙마다 정확히 하나의 소스/목적지 지정 필수 (precondition)

#### Outputs
- `security_group_id`: Security Group ID
- `security_group_arn`: Security Group ARN
- `security_group_name`: Security Group 이름
- `security_group_vpc_id`: VPC ID

### Configuration

#### Required Variables
- `name`: Security Group 이름 (kebab-case)
- `vpc_id`: VPC ID
- `environment`: 환경 (dev/staging/prod)
- `service_name`: 서비스 이름 (kebab-case)
- `team`: 담당 팀 (kebab-case)
- `owner`: 리소스 소유자 (이메일 또는 kebab-case)
- `cost_center`: 비용 센터 (kebab-case)

#### Optional Variables - General
- `description`: Security Group 설명 (기본값: "Managed by Terraform")
- `type`: SG 타입 (기본값: "custom")
- `revoke_rules_on_delete`: 삭제 시 규칙 먼저 제거 (기본값: false)
- `enable_default_egress`: 기본 egress 규칙 (기본값: true)
- `project`: 프로젝트 이름 (기본값: "infrastructure")
- `data_class`: 데이터 분류 (기본값: "internal")
- `additional_tags`: 추가 태그 (기본값: {})

#### Optional Variables - ALB Type
- `alb_enable_http`: HTTP 활성화 (기본값: true)
- `alb_enable_https`: HTTPS 활성화 (기본값: true)
- `alb_http_port`: HTTP 포트 (기본값: 80)
- `alb_https_port`: HTTPS 포트 (기본값: 443)
- `alb_ingress_cidr_blocks`: CIDR 블록 목록 (기본값: ["0.0.0.0/0"])

#### Optional Variables - ECS Type
- `ecs_ingress_from_alb_sg_id`: ALB SG ID (기본값: null)
- `ecs_container_port`: 컨테이너 포트 (기본값: 8080)
- `ecs_additional_ingress_sg_ids`: 추가 SG ID 목록 (기본값: [])

#### Optional Variables - RDS Type
- `rds_ingress_from_ecs_sg_id`: ECS SG ID (기본값: null)
- `rds_port`: DB 포트 (기본값: 5432)
- `rds_additional_ingress_sg_ids`: 추가 SG ID 목록 (기본값: [])
- `rds_ingress_cidr_blocks`: CIDR 블록 목록 (기본값: [])

#### Optional Variables - VPC Endpoint Type
- `vpc_endpoint_port`: 엔드포인트 포트 (기본값: 443)
- `vpc_endpoint_ingress_cidr_blocks`: CIDR 블록 목록 (기본값: [])
- `vpc_endpoint_ingress_sg_ids`: SG ID 목록 (기본값: [])

#### Optional Variables - Custom Rules
- `custom_ingress_rules`: 커스텀 ingress 규칙 목록 (기본값: [])
- `custom_egress_rules`: 커스텀 egress 규칙 목록 (기본값: [])

### Dependencies
- **Terraform**: >= 1.5.0
- **AWS Provider**: >= 5.0 (VPC Security Group Rule 리소스 필요)
- **Modules**: common-tags (태깅)

### Resources Created
- `aws_security_group.this`: 메인 Security Group
- `aws_vpc_security_group_ingress_rule.alb-http`: ALB HTTP ingress (조건부)
- `aws_vpc_security_group_ingress_rule.alb-https`: ALB HTTPS ingress (조건부)
- `aws_vpc_security_group_ingress_rule.ecs-from-alb`: ECS ingress from ALB (조건부)
- `aws_vpc_security_group_ingress_rule.ecs-additional`: ECS 추가 ingress (조건부)
- `aws_vpc_security_group_ingress_rule.rds-from-ecs`: RDS ingress from ECS (조건부)
- `aws_vpc_security_group_ingress_rule.rds-additional`: RDS 추가 ingress (조건부)
- `aws_vpc_security_group_ingress_rule.rds-cidr`: RDS CIDR ingress (조건부)
- `aws_vpc_security_group_ingress_rule.vpc-endpoint-cidr`: VPC Endpoint CIDR ingress (조건부)
- `aws_vpc_security_group_ingress_rule.vpc-endpoint-sg`: VPC Endpoint SG ingress (조건부)
- `aws_vpc_security_group_ingress_rule.custom`: 커스텀 ingress (for_each)
- `aws_vpc_security_group_egress_rule.default`: 기본 egress (조건부)
- `aws_vpc_security_group_egress_rule.custom`: 커스텀 egress (for_each)

### Security Features
- **최소 권한 원칙**: 타입별 필요한 규칙만 활성화
- **Security Group 참조 우선**: CIDR보다 SG 참조 권장
- **규칙 검증**: 소스/목적지 중복 지정 방지 (precondition)
- **안전한 삭제**: revoke_rules_on_delete 옵션
- **태그 기반 추적**: 모든 리소스 및 규칙에 태그 적용

### Documentation
- **README.md**: 전체 사용 가이드 (한국어)
  - 개요 및 주요 기능
  - 타입별 사용 예제 (ALB, ECS, RDS, VPC Endpoint, Custom)
  - 다계층 아키텍처 예제
  - 전체 입력 변수 상세 설명
  - 출력값 및 리소스 목록
  - 보안 고려사항 및 베스트 프랙티스
  - 태깅 전략
  - 제한 사항 및 문제 해결 가이드

- **CHANGELOG.md**: 버전별 변경 이력 (이 문서)

### Notes
- 초기 안정 버전 (v1.0.0)
- 프로덕션 사용 가능
- 모든 타입 (alb, ecs, rds, vpc-endpoint, custom) 완전 지원
- AWS Provider 5.0+ 전용 (VPC Security Group Rule 리소스 사용)

---

## Version Format

버전 번호는 Semantic Versioning을 따릅니다: MAJOR.MINOR.PATCH

- **MAJOR**: 호환성이 깨지는 변경
- **MINOR**: 하위 호환성을 유지하는 기능 추가
- **PATCH**: 하위 호환성을 유지하는 버그 수정
