output "bucket_id" {
  description = "The ID of the website bucket"
  value       = module.website_bucket.bucket_id
}

output "bucket_arn" {
  description = "The ARN of the website bucket"
  value       = module.website_bucket.bucket_arn
}

output "website_endpoint" {
  description = "The website endpoint URL"
  value       = module.website_bucket.website_endpoint
}

output "website_domain" {
  description = "The website domain"
  value       = module.website_bucket.website_domain
}
