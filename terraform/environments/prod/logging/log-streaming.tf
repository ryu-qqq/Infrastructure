# ============================================================================
# Log Streaming System - Data Sources
# (Firehose infrastructure removed - migrated to Kinesis Data Streams)
# See: kinesis-log-stream.tf
# ============================================================================

# ============================================================================
# Data Sources (Shared)
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# OpenSearch domain is now managed as a Terraform resource
# See: opensearch.tf (aws_opensearch_domain.logs)

# ============================================================================
# DEPRECATED: Firehose Infrastructure
# The following resources have been removed and replaced with Kinesis Data Streams:
# - aws_kinesis_firehose_delivery_stream.logs_to_opensearch
# - aws_lambda_function.log_transformer
# - aws_iam_role.firehose_opensearch
# - aws_iam_role.cloudwatch_to_firehose
# - module.firehose_backup_bucket
# - Related subscription filters (now in kinesis-log-stream.tf)
# - SSM parameters for Firehose (replaced with Kinesis parameters)
#
# New architecture: kinesis-log-stream.tf
# CloudWatch Logs → Kinesis Data Streams → Lambda (log-router) → OpenSearch
# ============================================================================
