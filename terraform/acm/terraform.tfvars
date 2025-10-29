# ACM Certificate Configuration
# Terraform Variables for AWS Certificate Manager

# Route53 Hosted Zone ID for DNS validation
# Note: Once Route53 module is applied and SSM Parameter is created,
# this can be removed and ACM will automatically lookup from SSM
route53_zone_id = "Z104656329CL6XBYE8OIJ"

# Domain configuration
domain_name = "set-of.com"
environment = "prod"

# Monitoring
enable_expiration_alarm = true
