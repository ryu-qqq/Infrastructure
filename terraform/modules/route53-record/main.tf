# Route53 Record Module
# Reusable module for creating DNS records with standardized configuration

resource "aws_route53_record" "this" {
  zone_id = var.zone_id
  name    = var.name
  type    = var.type
  ttl     = var.alias_configuration != null ? null : var.ttl

  # Simple records (A, AAAA, CNAME, TXT, etc.)
  records = var.alias_configuration != null ? null : var.records

  # Alias records (for AWS resources like ALB, CloudFront)
  dynamic "alias" {
    for_each = var.alias_configuration != null ? [var.alias_configuration] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  # Weighted routing policy
  dynamic "weighted_routing_policy" {
    for_each = var.weighted_routing_policy != null ? [var.weighted_routing_policy] : []
    content {
      weight = weighted_routing_policy.value.weight
    }
  }

  # Geolocation routing policy
  dynamic "geolocation_routing_policy" {
    for_each = var.geolocation_routing_policy != null ? [var.geolocation_routing_policy] : []
    content {
      continent   = geolocation_routing_policy.value.continent
      country     = geolocation_routing_policy.value.country
      subdivision = geolocation_routing_policy.value.subdivision
    }
  }

  # Failover routing policy
  dynamic "failover_routing_policy" {
    for_each = var.failover_routing_policy != null ? [var.failover_routing_policy] : []
    content {
      type = failover_routing_policy.value.type
    }
  }

  # Set identifier for routing policies
  set_identifier = var.set_identifier

  # Health check association
  health_check_id = var.health_check_id

  # Allow overwrite of existing records
  allow_overwrite = var.allow_overwrite
}
