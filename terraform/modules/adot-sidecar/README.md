# ADOT Sidecar Module

AWS Distro for OpenTelemetry (ADOT) sidecar container module for ECS tasks.

## Usage

```hcl
module "adot_sidecar" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/adot-sidecar?ref=main"

  project_name      = "fileflow"
  service_name      = "web-api"
  aws_region        = "ap-northeast-2"
  amp_workspace_arn = "arn:aws:aps:ap-northeast-2:123456789:workspace/ws-xxx"
  log_group_name    = "/aws/ecs/fileflow-web-api-prod/application"
}

# Use in task definition
resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([
    {
      name  = "app"
      image = "app:latest"
      # ... app container config
    },
    module.adot_sidecar.container_definition
  ])
}

# Attach IAM policy to task role
resource "aws_iam_role_policy" "adot" {
  name   = "adot-policy"
  role   = aws_iam_role.task.id
  policy = module.adot_sidecar.iam_policy_document
}
```

## Outputs

- `container_definition` - ADOT container definition to merge with task definition
- `iam_policy_document` - IAM policy for AMP write and S3 config access
- `otel_config_url` - URL where OTEL config should be placed
