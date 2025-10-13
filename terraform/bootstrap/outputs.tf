# Outputs for Bootstrap Module
#
# These outputs provide the necessary information for configuring
# Terraform backend in other modules.

output "terraform_backend_config" {
  description = "Backend configuration for other Terraform modules"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.terraform_lock.name
    encrypt        = true
    kms_key_id     = aws_kms_key.terraform_state.id
  }
}

output "backend_config_snippet" {
  description = "Ready-to-use backend configuration snippet for other modules"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.id}"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.terraform_lock.name}"
      encrypt        = true
      kms_key_id     = "${aws_kms_key.terraform_state.id}"
      # key = "path/to/terraform.tfstate" # Set this per module
    }
  EOT
}

output "summary" {
  description = "Summary of created resources"
  value = {
    s3_bucket      = aws_s3_bucket.terraform_state.id
    s3_bucket_arn  = aws_s3_bucket.terraform_state.arn
    dynamodb_table = aws_dynamodb_table.terraform_lock.name
    kms_key_id     = aws_kms_key.terraform_state.id
    kms_key_arn    = aws_kms_key.terraform_state.arn
    region         = var.aws_region
  }
}
