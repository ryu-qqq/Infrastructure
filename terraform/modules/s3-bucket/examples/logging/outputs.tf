output "bucket_id" {
  description = "The ID of the logs bucket"
  value       = module.logs_bucket.bucket_id
}

output "bucket_arn" {
  description = "The ARN of the logs bucket"
  value       = module.logs_bucket.bucket_arn
}

output "bucket_domain_name" {
  description = "The domain name of the logs bucket"
  value       = module.logs_bucket.bucket_domain_name
}
