# ============================================================================
# Log Subscription Filter V2 Module
# CloudWatch Logs → Kinesis Data Streams (for OpenSearch routing)
# ============================================================================

# SSM 파라미터에서 Kinesis 정보 조회
data "aws_ssm_parameter" "kinesis_stream_arn" {
  name = "/shared/logging/kinesis-stream-arn"
}

data "aws_ssm_parameter" "cloudwatch_to_kinesis_role_arn" {
  name = "/shared/logging/cloudwatch-to-kinesis-role-arn"
}

# CloudWatch Logs Subscription Filter → Kinesis
resource "aws_cloudwatch_log_subscription_filter" "to_kinesis" {
  name            = "${var.service_name}-to-kinesis"
  log_group_name  = var.log_group_name
  filter_pattern  = var.filter_pattern
  destination_arn = data.aws_ssm_parameter.kinesis_stream_arn.value
  role_arn        = data.aws_ssm_parameter.cloudwatch_to_kinesis_role_arn.value
}
