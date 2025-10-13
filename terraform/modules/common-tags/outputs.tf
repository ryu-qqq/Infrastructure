# Output standardized tags

output "tags" {
  description = "Complete set of standardized tags"
  value       = local.tags
}

output "required_tags" {
  description = "Only the required tags"
  value       = local.required_tags
}
