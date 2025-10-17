# {Module Name} Terraform Module

<!-- 모듈의 간단한 설명 (1-2 문장) -->
{모듈 설명: 무엇을 생성하고 어떤 문제를 해결하는지}

## Features

<!-- 모듈이 제공하는 주요 기능 목록 -->
- ✅ {기능 1}
- ✅ {기능 2}
- ✅ {기능 3}
- ✅ 표준화된 태그 자동 적용 (common-tags 모듈 통합)
- ✅ {네이밍 규칙 검증 / 보안 설정 / 모니터링 통합 등}

## Usage

### Basic Example

```hcl
# 공통 태그 모듈 (모든 모듈에서 권장)
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "api-server"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}

# 기본 사용 예제
module "{module_name}" {
  source = "../../modules/{module-name}"

  # 필수 변수
  name = "my-resource"

  # 공통 태그 적용
  common_tags = module.common_tags.tags

  # 기타 필수 변수
  {variable_name} = {value}
}
```

### Advanced Example

```hcl
# 고급 기능을 활용한 예제
module "{module_name}" {
  source = "../../modules/{module-name}"

  # 필수 변수
  name = "my-resource"

  # 선택적 변수 (고급 설정)
  {optional_variable_1} = {value}
  {optional_variable_2} = {value}

  # 공통 태그
  common_tags = module.common_tags.tags
}
```

### Complete Example

전체 기능을 활용한 실제 운영 시나리오는 [examples/complete](./examples/complete/) 디렉터리를 참조하세요.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name` | 리소스 이름 (네이밍 규칙 준수 필요) | `string` | - | yes |
| `common_tags` | common-tags 모듈에서 생성된 표준 태그 | `map(string)` | - | yes |
| `{variable}` | {변수 설명} | `{type}` | `{default}` | {yes/no} |

## Outputs

| Name | Description |
|------|-------------|
| `{output_name}` | {출력 값 설명} |
| `id` | 리소스의 고유 식별자 |
| `arn` | 리소스의 ARN (해당되는 경우) |
| `tags` | 리소스에 적용된 태그 |

## Resource Types

<!-- 이 모듈이 생성하는 AWS 리소스 목록 -->
- `aws_{resource_type}.this`
- `aws_{resource_type}.{optional}`

## Validation Rules

<!-- 모듈에 포함된 검증 규칙 -->
모듈은 다음 항목을 자동으로 검증합니다:

- ✅ 네이밍 규칙 준수 (해당되는 경우)
- ✅ 필수 변수 유효성
- ✅ {추가 검증 규칙}

유효하지 않은 입력은 `terraform plan` 단계에서 명확한 에러 메시지와 함께 실패합니다.

## Tags Applied

<!-- 리소스에 적용되는 태그 -->
모든 리소스는 자동으로 다음 태그를 받습니다:

**common-tags 모듈로부터:**
- `Environment` - 환경 (dev, staging, prod)
- `Service` - 서비스 이름
- `Team` - 담당 팀
- `Owner` - 소유자 이메일
- `CostCenter` - 비용 센터
- `ManagedBy` - "Terraform"
- `Project` - 프로젝트 이름

**모듈별 태그:**
- `Name` - 리소스 이름
- `{ModuleSpecificTag}` - {설명}

## Examples Directory

추가 사용 예제는 [examples/](./examples/) 디렉터리를 참조하세요:

- [basic/](./examples/basic/) - 최소 설정 예제
- [advanced/](./examples/advanced/) - 고급 기능 활용 예제
- [complete/](./examples/complete/) - 모든 기능을 활용한 실제 운영 시나리오

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Related Documentation

<!-- 관련 문서 링크 -->
- [모듈 디렉터리 구조](../../docs/MODULES_DIRECTORY_STRUCTURE.md)
- [태그 표준](../../docs/governance/TAGGING_STANDARDS.md)
- [{관련 문서 1}](링크)
- [{관련 문서 2}](링크)

## Changelog

변경 이력은 [CHANGELOG.md](./CHANGELOG.md)를 참조하세요.

## Epic & Tasks

<!-- Jira Epic 및 Task 참조 -->
- **Epic**: [IN-100 - 재사용 가능한 표준 모듈](https://ryuqqq.atlassian.net/browse/IN-100)
- **Task**: [IN-{XXX} - {Task 제목}](https://ryuqqq.atlassian.net/browse/IN-{XXX})

## License

Internal use only - Infrastructure Team

---

<!-- 선택적 섹션들 -->

## Advanced Configuration

### {고급 기능 1}
{상세 설명 및 예제}

### {고급 기능 2}
{상세 설명 및 예제}

## Troubleshooting

### {일반적인 문제 1}
**증상**: {문제 설명}
**해결**: {해결 방법}

### {일반적인 문제 2}
**증상**: {문제 설명}
**해결**: {해결 방법}

## Migration Guide

### From {이전 버전}
{마이그레이션 가이드}

## Security Considerations

<!-- 보안 관련 고려사항 (해당되는 경우) -->
- {보안 고려사항 1}
- {보안 고려사항 2}

## Performance Considerations

<!-- 성능 관련 고려사항 (해당되는 경우) -->
- {성능 고려사항 1}
- {성능 고려사항 2}

## Cost Optimization

<!-- 비용 최적화 권장사항 (해당되는 경우) -->
- {비용 최적화 방안 1}
- {비용 최적화 방안 2}
