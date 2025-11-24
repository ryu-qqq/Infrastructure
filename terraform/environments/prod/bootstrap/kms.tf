# KMS key for Terraform state encryption
resource "aws_kms_key" "terraform-state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    {
      Owner       = var.owner
      CostCenter  = var.cost_center
      Environment = var.environment
      Lifecycle   = var.lifecycle
      DataClass   = var.data_class
      Service     = var.service
      ManagedBy   = "terraform"
      Project     = var.project
    },
    {
      Name      = "terraform-state-encryption"
      Component = "kms"
    }
  )
}

resource "aws_kms_alias" "terraform-state" {
  name          = local.kms_key_alias
  target_key_id = aws_kms_key.terraform-state.key_id
}
