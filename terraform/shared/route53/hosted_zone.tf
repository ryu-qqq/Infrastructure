# ============================================================================
# Route53 Hosted Zone
# ============================================================================

resource "aws_route53_zone" "main" {
  name          = var.domain_name
  comment       = var.comment != "" ? var.comment : "Managed by Terraform for ${var.project_name}"
  force_destroy = var.force_destroy

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-${local.zone_name}"
      Component = "dns"
      Domain    = var.domain_name
    }
  )

  # Import된 리소스 - 기존 Hosted Zone 속성 보존
  lifecycle {
    ignore_changes = [
      name,             # Import된 Hosted Zone의 도메인명은 변경 불가
      vpc,              # Private Hosted Zone의 경우 VPC 연결 보존
      delegation_set_id, # Delegation Set이 있는 경우 보존
      tags,             # Import된 Hosted Zone의 기존 태그 보존 (IAM 권한 제약)
      tags_all          # Provider default_tags와 충돌 방지
    ]
  }
}
