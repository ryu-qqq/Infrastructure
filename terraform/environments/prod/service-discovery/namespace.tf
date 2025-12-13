# Cloud Map Private DNS Namespace
#
# This creates a private DNS namespace for service discovery within the VPC.
# Services registered here will be accessible via DNS: {service}.connectly.local
#
# Architecture:
# ┌─────────────────────────────────────────────────────────────────┐
# │                  AWS Cloud Map Namespace                        │
# │                    (connectly.local)                            │
# ├─────────────────────────────────────────────────────────────────┤
# │                                                                 │
# │   authhub.connectly.local ──────┐                               │
# │   fileflow.connectly.local ─────┼──→ ECS Task IP Auto Register  │
# │   commerce.connectly.local ─────┘                               │
# │                                                                 │
# └─────────────────────────────────────────────────────────────────┘

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = var.namespace_name
  description = var.namespace_description
  vpc         = local.vpc_id

  tags = merge(
    local.required_tags,
    {
      Name        = var.namespace_name
      Component   = "service-discovery"
      Description = "Cloud Map namespace for internal service discovery"
    }
  )
}
