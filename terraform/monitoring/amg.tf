# Amazon Managed Grafana (AMG) Workspace
# IN-117: Monitoring system setup

# ============================================================================
# AMG Workspace
# ============================================================================

resource "aws_grafana_workspace" "main" {
  name                     = "${local.name_prefix}-${var.amg_workspace_name}"
  account_access_type      = var.amg_account_access_type
  authentication_providers = var.amg_authentication_providers
  permission_type          = var.amg_permission_type
  data_sources             = var.amg_data_sources
  role_arn                 = aws_iam_role.grafana-workspace.arn

  # Network access configuration (optional - for VPC access)
  # network_access_control {
  #   prefix_list_ids = []
  #   vpce_ids        = []
  # }

  # Organization access (if using ORGANIZATION account_access_type)
  # organization_role_name = "GrafanaOrganizationAccess"

  # Notification destinations (optional - for alerts)
  # notification_destinations = ["SNS"]

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-amg"
      Component   = "amg"
      Description = "Amazon Managed Grafana workspace for infrastructure observability"
    }
  )

  lifecycle {
    # Prevent accidental deletion of Grafana workspace
    prevent_destroy = false # Set to true in production
  }
}

# ============================================================================
# AMG IAM Role (Required for CURRENT_ACCOUNT access type)
# ============================================================================

resource "aws_iam_role" "grafana-workspace" {
  name = "${local.name_prefix}-grafana-workspace-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "grafana.amazonaws.com"
      }
    }]
  })

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-grafana-workspace-role"
      Component   = "iam"
      Description = "IAM role for Grafana workspace"
    }
  )
}

# ============================================================================
# AMG Workspace SAML Configuration (Optional)
# ============================================================================

# SAML configuration for enterprise SSO
# resource "aws_grafana_workspace_saml_configuration" "main" {
#   workspace_id = aws_grafana_workspace.main.id
#
#   idp_metadata_url = var.saml_idp_metadata_url
#   # OR
#   # idp_metadata_xml = file("${path.module}/configs/saml-metadata.xml")
#
#   admin_role_values  = ["Admin"]
#   editor_role_values = ["Editor"]
#   role_assertion     = "Role"
#
#   email_assertion         = "Email"
#   login_assertion         = "Email"
#   name_assertion          = "DisplayName"
#   org_assertion           = "Organization"
#   allowed_organizations   = [var.organization_name]
#   login_validity_duration = 60
# }

# ============================================================================
# AMG Workspace API Key (For CI/CD and Automation)
# ============================================================================

# API key for automated dashboard provisioning
# resource "aws_grafana_workspace_api_key" "automation" {
#   key_name        = "automation-key"
#   key_role        = "ADMIN" # or "EDITOR", "VIEWER"
#   seconds_to_live = 2592000 # 30 days
#   workspace_id    = aws_grafana_workspace.main.id
# }

# Store API key in Secrets Manager for secure access
# resource "aws_secretsmanager_secret" "grafana_api_key" {
#   name = "${local.name_prefix}-grafana-api-key"
#   description = "API key for Grafana workspace automation"
#
#   tags = local.required_tags
# }

# resource "aws_secretsmanager_secret_version" "grafana_api_key" {
#   secret_id     = aws_secretsmanager_secret.grafana_api_key.id
#   secret_string = aws_grafana_workspace_api_key.automation.key
# }

# ============================================================================
# AMG License Association (Optional - for Enterprise features)
# ============================================================================

# If you have Grafana Enterprise license
# resource "aws_grafana_license_association" "enterprise" {
#   workspace_id  = aws_grafana_workspace.main.id
#   license_type  = "ENTERPRISE" # or "ENTERPRISE_FREE_TRIAL"
# }
