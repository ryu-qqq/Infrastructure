# Advanced Route53 Record Examples
# Alias records, routing policies, and health checks

# Alias record for ALB
module "alb_alias_record" {
  source = "../../"

  zone_id = "Z1234567890ABC"
  name    = "app.set-of.com"
  type    = "A"

  alias_configuration = {
    name                   = "alb-123456.ap-northeast-2.elb.amazonaws.com"
    zone_id                = "Z1234567890DEF" # ALB zone ID
    evaluate_target_health = true
  }
}

# Weighted routing policy for canary deployment
module "canary_primary" {
  source = "../../"

  zone_id        = "Z1234567890ABC"
  name           = "api.set-of.com"
  type           = "A"
  ttl            = 60
  records        = ["203.0.113.10"]
  set_identifier = "primary-90"

  weighted_routing_policy = {
    weight = 90
  }
}

module "canary_secondary" {
  source = "../../"

  zone_id        = "Z1234567890ABC"
  name           = "api.set-of.com"
  type           = "A"
  ttl            = 60
  records        = ["203.0.113.20"]
  set_identifier = "canary-10"

  weighted_routing_policy = {
    weight = 10
  }
}

# Failover routing with health check
module "failover_primary" {
  source = "../../"

  zone_id         = "Z1234567890ABC"
  name            = "service.set-of.com"
  type            = "A"
  ttl             = 60
  records         = ["203.0.113.30"]
  set_identifier  = "primary"
  health_check_id = "abc123-health-check-id"

  failover_routing_policy = {
    type = "PRIMARY"
  }
}

module "failover_secondary" {
  source = "../../"

  zone_id        = "Z1234567890ABC"
  name           = "service.set-of.com"
  type           = "A"
  ttl            = 60
  records        = ["203.0.113.40"]
  set_identifier = "secondary"

  failover_routing_policy = {
    type = "SECONDARY"
  }
}

# Geolocation routing for region-specific content
module "geo_routing_asia" {
  source = "../../"

  zone_id        = "Z1234567890ABC"
  name           = "cdn.set-of.com"
  type           = "A"
  ttl            = 300
  records        = ["203.0.113.50"]
  set_identifier = "asia"

  geolocation_routing_policy = {
    continent = "AS"
  }
}

module "geo_routing_korea" {
  source = "../../"

  zone_id        = "Z1234567890ABC"
  name           = "cdn.set-of.com"
  type           = "A"
  ttl            = 300
  records        = ["203.0.113.60"]
  set_identifier = "korea"

  geolocation_routing_policy = {
    country = "KR"
  }
}
