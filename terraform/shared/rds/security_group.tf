# ============================================================================
# Security Group
# ============================================================================

resource "aws_security_group" "main" {
  name        = "prod-shared-mysql-sg"  # 기존 리소스 이름 유지
  description = "Security group for shared MySQL RDS instance"  # 기존 description 유지
  vpc_id      = var.vpc_id

  tags = merge(
    local.required_tags,
    {
      Name      = "prod-shared-mysql-sg"
      Component = "database"
    }
  )

  # Import된 리소스 - 기존 태그, 이름, description, ingress/egress 보존
  lifecycle {
    ignore_changes = [
      tags,
      name,
      description,
      ingress,  # 기존 inline rules 보존
      egress    # 기존 inline rules 보존
    ]
  }
}

# NOTE: 기존 Security Group은 inline rules를 사용하고 있어 별도 rule 리소스 생성하지 않음
# lifecycle ignore_changes [ingress, egress]로 기존 inline rules 보존
#
# 기존 규칙:
# - Ingress: 10.0.0.0/16 → 3306 (CIDR)
# - Ingress: sg-02a1271bdfe47917e, sg-0cddfe39fb791a002, sg-0e11b4a1e012204b2 → 3306 (Security Groups)
# - Egress: 0.0.0.0/0 ALL (All traffic)
