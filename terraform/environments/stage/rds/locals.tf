# Local Variables

locals {
  # Common naming prefix
  name_prefix = "${var.environment}-${var.identifier}"

  # Final snapshot identifier
  final_snapshot_identifier = var.final_snapshot_identifier != null ? var.final_snapshot_identifier : "${local.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Required tags for all resources
  # Note: Environment, Service, Team, Owner, CostCenter, ManagedBy, Project, DataClass, Stack은
  # provider.tf의 default_tags에서 이미 적용됨
  # 여기서는 리소스별 추가 태그나 Name 태그에만 사용
  required_tags = {
    # provider default_tags와 동일하게 유지 (리소스에서 merge 시 사용)
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
  }
}
