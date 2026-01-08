# ============================================================================
# OpenSearch Domain for Centralized Logging
# ============================================================================
#
# This OpenSearch domain stores application logs from all services.
# Logs are ingested via Kinesis Data Streams → Lambda → OpenSearch pipeline.
#
# Upgrade History:
# - 2026-01-09: Migrated to Terraform management, upgraded to t3.large
# ============================================================================

# ============================================================================
# Data Source: Existing KMS Key (used by the imported OpenSearch domain)
# ============================================================================

data "aws_kms_key" "opensearch" {
  key_id = var.opensearch_kms_key_id
}

# ============================================================================
# OpenSearch Domain
# ============================================================================

resource "aws_opensearch_domain" "logs" {
  domain_name    = var.opensearch_domain_name
  engine_version = var.opensearch_engine_version

  # Cluster Configuration - Upgraded from t3.small to t3.large
  cluster_config {
    instance_type            = var.opensearch_instance_type
    instance_count           = var.opensearch_instance_count
    dedicated_master_enabled = var.opensearch_dedicated_master_enabled
    zone_awareness_enabled   = var.opensearch_zone_awareness_enabled

    dynamic "zone_awareness_config" {
      for_each = var.opensearch_zone_awareness_enabled ? [1] : []
      content {
        availability_zone_count = var.opensearch_availability_zone_count
      }
    }
  }

  # EBS Storage Configuration
  ebs_options {
    ebs_enabled = true
    volume_type = var.opensearch_volume_type
    volume_size = var.opensearch_volume_size
    iops        = var.opensearch_iops
    throughput  = var.opensearch_throughput
  }

  # Encryption Configuration - Use existing KMS key
  encrypt_at_rest {
    enabled    = true
    kms_key_id = data.aws_kms_key.opensearch.arn
  }

  node_to_node_encryption {
    enabled = true
  }

  # Domain Endpoint Options
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  # Access Policy - Matching existing configuration
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpDelete",
          "es:ESHttpHead"
        ]
        Resource = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain_name}/*"
        Condition = {
          IpAddress = {
            "aws:sourceIp" = concat(
              [var.vpc_cidr_block],
              [for ip in var.opensearch_allowed_ips : "${ip}/32"]
            )
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpHead",
          "es:ESHttpDelete"
        ]
        Resource = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain_name}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = [
          "es:DescribeElasticsearchDomain",
          "es:DescribeElasticsearchDomains",
          "es:DescribeElasticsearchDomainConfig",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpGet",
          "es:ESHttpHead"
        ]
        Resource = [
          "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain_name}",
          "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain_name}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  # Software Update Options
  software_update_options {
    auto_software_update_enabled = false
  }

  # Advanced Options - Match existing
  advanced_options = {
    "indices.fielddata.cache.size"        = "20"
    "indices.query.bool.max_clause_count" = "1024"
  }

  # Off Peak Window Options - Match existing
  off_peak_window_options {
    enabled = true
    off_peak_window {
      window_start_time {
        hours   = 13
        minutes = 0
      }
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name      = var.opensearch_domain_name
      Component = "opensearch"
      Purpose   = "centralized-logging"
    }
  )

  lifecycle {
    prevent_destroy = true
    # Ignore changes to tags that were set via console
    ignore_changes = [
      tags["Component"],
      tags["Project"],
      tags_all["Component"],
      tags_all["Project"],
    ]
  }
}

# ============================================================================
# CloudWatch Alarms for OpenSearch
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "opensearch_jvm_memory_pressure" {
  alarm_name          = "${var.opensearch_domain_name}-jvm-memory-pressure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "JVMMemoryPressure"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "OpenSearch JVM memory pressure is above 80%"

  dimensions = {
    DomainName = var.opensearch_domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns

  tags = merge(
    local.common_tags,
    {
      Name      = "${var.opensearch_domain_name}-jvm-memory-alarm"
      Component = "opensearch"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "opensearch_cluster_status_red" {
  alarm_name          = "${var.opensearch_domain_name}-cluster-status-red"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ClusterStatus.red"
  namespace           = "AWS/ES"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "OpenSearch cluster status is RED"

  dimensions = {
    DomainName = var.opensearch_domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns

  tags = merge(
    local.common_tags,
    {
      Name      = "${var.opensearch_domain_name}-cluster-red-alarm"
      Component = "opensearch"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "opensearch_free_storage_space" {
  alarm_name          = "${var.opensearch_domain_name}-free-storage-space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/ES"
  period              = 300
  statistic           = "Minimum"
  threshold           = 5000 # 5GB
  alarm_description   = "OpenSearch free storage space is below 5GB"

  dimensions = {
    DomainName = var.opensearch_domain_name
    ClientId   = data.aws_caller_identity.current.account_id
  }

  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns

  tags = merge(
    local.common_tags,
    {
      Name      = "${var.opensearch_domain_name}-storage-alarm"
      Component = "opensearch"
    }
  )
}

# ============================================================================
# SSM Parameter Store - OpenSearch Endpoint
# ============================================================================

resource "aws_ssm_parameter" "opensearch_endpoint" {
  name        = "/${var.environment}/logging/opensearch/endpoint"
  description = "OpenSearch domain endpoint"
  type        = "String"
  value       = aws_opensearch_domain.logs.endpoint

  tags = merge(
    local.common_tags,
    {
      Name      = "${var.environment}-opensearch-endpoint"
      Component = "opensearch"
    }
  )
}

resource "aws_ssm_parameter" "opensearch_domain_arn" {
  name        = "/${var.environment}/logging/opensearch/domain-arn"
  description = "OpenSearch domain ARN"
  type        = "String"
  value       = aws_opensearch_domain.logs.arn

  tags = merge(
    local.common_tags,
    {
      Name      = "${var.environment}-opensearch-domain-arn"
      Component = "opensearch"
    }
  )
}
