# Basic Route53 Record Example
# Simple A record pointing to an IP address

module "simple_a_record" {
  source = "../../"

  zone_id = "Z1234567890ABC" # Replace with your hosted zone ID
  name    = "api.set-of.com"
  type    = "A"
  ttl     = 300
  records = ["203.0.113.10"]
}

# CNAME record example
module "cname_record" {
  source = "../../"

  zone_id = "Z1234567890ABC"
  name    = "www.set-of.com"
  type    = "CNAME"
  ttl     = 300
  records = ["set-of.com"]
}

# TXT record for domain verification
module "txt_record" {
  source = "../../"

  zone_id = "Z1234567890ABC"
  name    = "_verification.set-of.com"
  type    = "TXT"
  ttl     = 300
  records = ["google-site-verification=abc123"]
}
