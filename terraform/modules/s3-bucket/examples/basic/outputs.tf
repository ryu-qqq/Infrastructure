output "bucket_id" {
  description = "The ID of the bucket"
  value       = module.data_bucket.bucket_id
}

output "bucket_arn" {
  description = "The ARN of the bucket"
  value       = module.data_bucket.bucket_arn
}

output "bucket_domain_name" {
  description = "The domain name of the bucket"
  value       = module.data_bucket.bucket_domain_name
}
