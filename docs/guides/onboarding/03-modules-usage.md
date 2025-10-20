# 모듈 사용 가이드

중앙 인프라 모듈 참조 방법과 서비스 전용 모듈 생성 기준, Git URL 참조 패턴을 설명합니다.

## 중앙 인프라 모듈 사용
- 모듈 버전 고정(`?ref=`)으로 재현 가능성 보장
- 프로덕션 적용 전 개발 환경에서 테스트
- 모듈 README의 입력/출력 사양 확인

## 서비스 전용 모듈 생성 기준
- 중앙 모듈에 없는 서비스 특화 패턴
- 커스텀 비즈니스 로직 필요
- 복잡한 다중 리소스 조합

## Git URL 참조 기본 문법
```hcl
module "module_name" {
  source = "git::https://github.com/{org}/{repo}.git//{path}?ref={version}"
}
```

## 로컬 개발 시 참조
```hcl
module "app_service" {
  source = "../../modules/ecs-service"  # 개발/테스트 시
}
```

자세한 예시와 버전 관리 전략은 별도 문서를 참고하세요.
