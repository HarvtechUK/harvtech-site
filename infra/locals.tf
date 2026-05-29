locals {
  # --- Core naming ---
  rg_name      = "rg-${var.project}-site-${var.environment}-uks"
  storage_name = "st${var.project}site${var.environment}uks01"

  # --- Custom domains ---
  apex_domain = "harvtech.co.uk"
  www_domain  = "www.harvtech.co.uk"

  # --- Front Door ---
  fd_profile_name      = "afd-${var.project}-${var.environment}-uks"
  fd_endpoint_name     = "harvtech"
  fd_origin_group_name = "og-site"
  fd_origin_name       = "origin-storage-web"
  fd_route_name        = "route-default"
  fd_rule_set_name     = "rsapex"
  fd_rule_www_to_apex  = "wwwToApex"

  # --- WAF ---
  waf_policy_name      = "wafharvtechsite${var.environment}"
  waf_security_policy  = "sp-${var.project}-${var.environment}"
  waf_rate_limit_name  = "ratelimitperip"
  waf_rate_limit_count = 100 # requests per minute per client IP
}
