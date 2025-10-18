# KMS key for Terraform state encryption
resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name      = "terraform-state-encryption"
      Component = "kms"
    }
  )
}

resource "aws_kms_alias" "terraform_state" {
  name          = local.kms_key_alias
  target_key_id = aws_kms_key.terraform_state.key_id
}
