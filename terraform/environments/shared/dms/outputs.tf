# ============================================================================
# DMS Outputs
# ============================================================================

output "replication_instance_arn" {
  description = "ARN of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_arn
}

output "replication_instance_id" {
  description = "ID of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_id
}

output "replication_task_arn" {
  description = "ARN of the DMS replication task for luxurydb"
  value       = aws_dms_replication_task.luxurydb.replication_task_arn
}

output "source_endpoint_arn" {
  description = "ARN of the source (Prod) endpoint"
  value       = aws_dms_endpoint.source.endpoint_arn
}

output "target_endpoint_arn" {
  description = "ARN of the target (Stage) endpoint"
  value       = aws_dms_endpoint.target.endpoint_arn
}

output "dms_security_group_id" {
  description = "Security group ID of the DMS replication instance"
  value       = aws_security_group.dms.id
}
