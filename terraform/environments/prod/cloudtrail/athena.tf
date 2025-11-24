# Athena Configuration for CloudTrail Log Analysis
# Enables SQL-based querying of CloudTrail logs

# Athena Workgroup
resource "aws_athena_workgroup" "cloudtrail" {
  count = var.enable_athena ? 1 : 0
  name  = var.athena_workgroup_name

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${module.athena_results_bucket[0].bucket_id}/query-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = {
    Name        = var.athena_workgroup_name
    Component   = "athena"
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}

# Glue Database for CloudTrail logs
resource "aws_glue_catalog_database" "cloudtrail" {
  count = var.enable_athena ? 1 : 0
  name  = var.athena_database_name

  description = "Database for CloudTrail log analysis"

  tags = {
    Name        = var.athena_database_name
    Component   = "athena"
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}

# Glue Table for CloudTrail logs
resource "aws_glue_catalog_table" "cloudtrail" {
  count         = var.enable_athena ? 1 : 0
  name          = "cloudtrail_logs"
  database_name = aws_glue_catalog_database.cloudtrail[0].name
  description   = "CloudTrail logs table for Athena queries"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL                    = "TRUE"
    "projection.enabled"        = "true"
    "projection.region.type"    = "enum"
    "projection.region.values"  = "us-east-1,us-east-2,us-west-1,us-west-2,af-south-1,ap-east-1,ap-south-1,ap-northeast-3,ap-northeast-2,ap-southeast-1,ap-southeast-2,ap-northeast-1,ca-central-1,eu-central-1,eu-west-1,eu-west-2,eu-south-1,eu-west-3,eu-north-1,me-south-1,sa-east-1"
    "projection.date.type"      = "date"
    "projection.date.range"     = "2020/01/01,NOW"
    "projection.date.format"    = "yyyy/MM/dd"
    "storage.location.template" = "s3://${module.cloudtrail_logs_bucket.bucket_id}/${var.s3_key_prefix}/AWSLogs/${var.aws_account_id}/CloudTrail/$${region}/$${date}"
  }

  storage_descriptor {
    location      = "s3://${module.cloudtrail_logs_bucket.bucket_id}/${var.s3_key_prefix}/AWSLogs/${var.aws_account_id}/CloudTrail/"
    input_format  = "com.amazon.emr.cloudtrail.CloudTrailInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "com.amazon.emr.hive.serde.CloudTrailSerde"

      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "eventversion"
      type = "string"
    }

    columns {
      name = "useridentity"
      type = "struct<type:string,principalid:string,arn:string,accountid:string,invokedby:string,accesskeyid:string,userName:string,sessioncontext:struct<attributes:struct<mfaauthenticated:string,creationdate:string>,sessionissuer:struct<type:string,principalId:string,arn:string,accountId:string,userName:string>>>"
    }

    columns {
      name = "eventtime"
      type = "string"
    }

    columns {
      name = "eventsource"
      type = "string"
    }

    columns {
      name = "eventname"
      type = "string"
    }

    columns {
      name = "awsregion"
      type = "string"
    }

    columns {
      name = "sourceipaddress"
      type = "string"
    }

    columns {
      name = "useragent"
      type = "string"
    }

    columns {
      name = "errorcode"
      type = "string"
    }

    columns {
      name = "errormessage"
      type = "string"
    }

    columns {
      name = "requestparameters"
      type = "string"
    }

    columns {
      name = "responseelements"
      type = "string"
    }

    columns {
      name = "additionaleventdata"
      type = "string"
    }

    columns {
      name = "requestid"
      type = "string"
    }

    columns {
      name = "eventid"
      type = "string"
    }

    columns {
      name = "resources"
      type = "array<struct<ARN:string,accountId:string,type:string>>"
    }

    columns {
      name = "eventtype"
      type = "string"
    }

    columns {
      name = "apiversion"
      type = "string"
    }

    columns {
      name = "readonly"
      type = "string"
    }

    columns {
      name = "recipientaccountid"
      type = "string"
    }

    columns {
      name = "serviceeventdetails"
      type = "string"
    }

    columns {
      name = "sharedeventid"
      type = "string"
    }

    columns {
      name = "vpcendpointid"
      type = "string"
    }
  }

  partition_keys {
    name = "region"
    type = "string"
  }

  partition_keys {
    name = "date"
    type = "string"
  }
}

# Named Queries for common CloudTrail analysis
resource "aws_athena_named_query" "unauthorized-api-calls" {
  count     = var.enable_athena ? 1 : 0
  name      = "unauthorized-api-calls"
  workgroup = aws_athena_workgroup.cloudtrail[0].id
  database  = aws_glue_catalog_database.cloudtrail[0].name
  query     = <<-SQL
    SELECT
      useridentity.arn,
      eventname,
      sourceipaddress,
      eventtime,
      errorcode,
      errormessage
    FROM ${aws_glue_catalog_table.cloudtrail[0].name}
    WHERE errorcode IN ('UnauthorizedOperation', 'AccessDenied')
      AND date >= date_format(current_date - interval '7' day, '%Y/%m/%d')
    ORDER BY eventtime DESC
    LIMIT 100;
  SQL

  description = "Find unauthorized API calls in the last 7 days"
}

resource "aws_athena_named_query" "root-account-usage" {
  count     = var.enable_athena ? 1 : 0
  name      = "root-account-usage"
  workgroup = aws_athena_workgroup.cloudtrail[0].id
  database  = aws_glue_catalog_database.cloudtrail[0].name
  query     = <<-SQL
    SELECT
      eventtime,
      eventname,
      sourceipaddress,
      useragent,
      requestparameters,
      responseelements
    FROM ${aws_glue_catalog_table.cloudtrail[0].name}
    WHERE useridentity.type = 'Root'
      AND date >= date_format(current_date - interval '30' day, '%Y/%m/%d')
    ORDER BY eventtime DESC;
  SQL

  description = "Find root account usage in the last 30 days"
}

resource "aws_athena_named_query" "console-login-failures" {
  count     = var.enable_athena ? 1 : 0
  name      = "console-login-failures"
  workgroup = aws_athena_workgroup.cloudtrail[0].id
  database  = aws_glue_catalog_database.cloudtrail[0].name
  query     = <<-SQL
    SELECT
      useridentity.principalid,
      eventtime,
      sourceipaddress,
      useragent,
      responseelements
    FROM ${aws_glue_catalog_table.cloudtrail[0].name}
    WHERE eventname = 'ConsoleLogin'
      AND errorcode = 'Failed authentication'
      AND date >= date_format(current_date - interval '7' day, '%Y/%m/%d')
    ORDER BY eventtime DESC
    LIMIT 100;
  SQL

  description = "Find failed console login attempts in the last 7 days"
}

resource "aws_athena_named_query" "iam-policy-changes" {
  count     = var.enable_athena ? 1 : 0
  name      = "iam-policy-changes"
  workgroup = aws_athena_workgroup.cloudtrail[0].id
  database  = aws_glue_catalog_database.cloudtrail[0].name
  query     = <<-SQL
    SELECT
      useridentity.arn,
      eventtime,
      eventname,
      requestparameters,
      responseelements
    FROM ${aws_glue_catalog_table.cloudtrail[0].name}
    WHERE eventsource = 'iam.amazonaws.com'
      AND eventname IN (
        'PutUserPolicy', 'PutGroupPolicy', 'PutRolePolicy',
        'CreatePolicy', 'DeletePolicy', 'CreatePolicyVersion',
        'AttachUserPolicy', 'AttachGroupPolicy', 'AttachRolePolicy',
        'DetachUserPolicy', 'DetachGroupPolicy', 'DetachRolePolicy'
      )
      AND date >= date_format(current_date - interval '30' day, '%Y/%m/%d')
    ORDER BY eventtime DESC;
  SQL

  description = "Find IAM policy changes in the last 30 days"
}
