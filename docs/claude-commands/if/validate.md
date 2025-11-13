# Infrastructure Validation Command

**Task**: 인프라 프로젝트의 Terraform 모듈 구조와 유효성을 검증합니다.

## 실행 내용

1. **프로젝트 위치 확인**
   - infrastructure 프로젝트 경로: `/Users/sangwon-ryu/infrastructure`
   - 검증 스크립트: `./scripts/validators/validate-modules.sh`

2. **검증 실행**
   ```bash
   cd /Users/sangwon-ryu/infrastructure
   ./scripts/validators/validate-modules.sh [module-name]
   ```

3. **검증 항목**
   - 필수 파일 존재 확인 (main.tf, variables.tf, outputs.tf, versions.tf)
   - terraform init 성공 여부
   - terraform validate 성공 여부
   - 예제 코드 유효성 (examples/)
   - 거버넌스 규칙 준수 (태그, 암호화, 네이밍)

4. **결과 보고**
   - 각 모듈별 검증 결과
   - 발견된 오류 및 경고사항
   - 전체 요약 (통과/실패 모듈 수)

## 사용 예시

```bash
# 전체 모듈 검증
/if/validate

# 특정 모듈만 검증
/if/validate alb
/if/validate ecs-service
```

## 주의사항

- infrastructure 프로젝트 경로가 변경된 경우 이 파일에서 경로를 수정하세요
- 검증 실패 시 각 오류 메시지를 확인하고 수정이 필요합니다
- common-tags 모듈은 locals만 포함하므로 terraform validate를 스킵합니다
