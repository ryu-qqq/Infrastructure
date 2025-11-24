# CloudWatch Alarms for RDS
# Note: CloudWatch Log Groups are created by RDS module automatically when enabled_cloudwatch_logs_exports is set

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "cpu-utilization" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-cpu-utilization"
  alarm_description   = "RDS CPU utilization is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_utilization_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  alarm_actions = [data.terraform_remote_state.monitoring.outputs.sns_topic_warning_arn]
  ok_actions    = [data.terraform_remote_state.monitoring.outputs.sns_topic_info_arn]

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name = "${local.name_prefix}-cpu-alarm"
    }
  )
}

# Free Storage Space Alarm
resource "aws_cloudwatch_metric_alarm" "free-storage-space" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-free-storage-space"
  alarm_description   = "RDS free storage space is too low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.free_storage_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  alarm_actions = [data.terraform_remote_state.monitoring.outputs.sns_topic_critical_arn]
  ok_actions    = [data.terraform_remote_state.monitoring.outputs.sns_topic_info_arn]

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name = "${local.name_prefix}-storage-alarm"
    }
  )
}

# Freeable Memory Alarm
resource "aws_cloudwatch_metric_alarm" "freeable-memory" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-freeable-memory"
  alarm_description   = "RDS freeable memory is too low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.freeable_memory_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  alarm_actions = [data.terraform_remote_state.monitoring.outputs.sns_topic_critical_arn]
  ok_actions    = [data.terraform_remote_state.monitoring.outputs.sns_topic_info_arn]

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name = "${local.name_prefix}-memory-alarm"
    }
  )
}

# Database Connections Alarm
resource "aws_cloudwatch_metric_alarm" "database-connections" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-database-connections"
  alarm_description   = "RDS database connections are too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.database_connections_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  alarm_actions = [data.terraform_remote_state.monitoring.outputs.sns_topic_critical_arn]
  ok_actions    = [data.terraform_remote_state.monitoring.outputs.sns_topic_info_arn]

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name = "${local.name_prefix}-connections-alarm"
    }
  )
}

# Read Latency Alarm
resource "aws_cloudwatch_metric_alarm" "read-latency" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-read-latency"
  alarm_description   = "RDS read latency is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.1 # 100ms
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  alarm_actions = [data.terraform_remote_state.monitoring.outputs.sns_topic_warning_arn]
  ok_actions    = [data.terraform_remote_state.monitoring.outputs.sns_topic_info_arn]

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name = "${local.name_prefix}-read-latency-alarm"
    }
  )
}

# Write Latency Alarm
resource "aws_cloudwatch_metric_alarm" "write-latency" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-write-latency"
  alarm_description   = "RDS write latency is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.1 # 100ms
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  alarm_actions = [data.terraform_remote_state.monitoring.outputs.sns_topic_warning_arn]
  ok_actions    = [data.terraform_remote_state.monitoring.outputs.sns_topic_info_arn]

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name = "${local.name_prefix}-write-latency-alarm"
    }
  )
}
