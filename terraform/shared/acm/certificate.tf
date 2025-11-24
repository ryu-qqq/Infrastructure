# ============================================================================
# ACM Certificate
# ============================================================================

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = var.validation_method

  # Import된 리소스 - 기존 인증서 속성 보존
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      domain_name,              # Import된 인증서의 도메인은 변경 불가
      subject_alternative_names, # Import된 인증서의 SAN은 변경 불가
      validation_method,        # Import된 인증서의 검증 방식 변경 불가
      options,                  # Certificate transparency logging 등 기존 옵션 보존
      tags,                     # Import된 인증서의 기존 태그 보존 (IAM 권한 제약)
      tags_all                  # Provider default_tags와 충돌 방지
    ]
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-${local.cert_name}"
      Component = "certificate"
    }
  )
}
