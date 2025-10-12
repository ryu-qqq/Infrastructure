# Outputs for Atlantis test infrastructure

output "test_bucket_name" {
  description = "Name of the test S3 bucket"
  value       = aws_s3_bucket.atlantis_test.id
}

output "test_bucket_arn" {
  description = "ARN of the test S3 bucket"
  value       = aws_s3_bucket.atlantis_test.arn
}

output "test_bucket_region" {
  description = "Region of the test S3 bucket"
  value       = aws_s3_bucket.atlantis_test.region
}
