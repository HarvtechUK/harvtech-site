locals {
  # --- Core naming (from the shared convention module) ---
  rg_name         = module.naming.resource_group
  storage_name    = module.naming.storage_account
  fd_profile_name = module.naming.cdn_frontdoor_profile
  waf_policy_name = module.naming.cdn_frontdoor_firewall_policy
  law_name        = module.naming.log_analytics_workspace

  # --- Custom domains ---
  apex_domain = "harvtech.co.uk"
  www_domain  = "www.harvtech.co.uk"

  # --- Front Door child resources ---
  # These are FD-internal names (scoped inside the profile, invisible
  # in cost reports and the portal's top-level views), so they stay
  # descriptive rather than CAF-patterned.
  fd_endpoint_name     = "harvtech"
  fd_origin_group_name = "og-site"
  fd_origin_name       = "origin-storage-web"
  fd_route_name        = "route-default"
  fd_rule_set_name     = "rsapex"
  fd_rule_www_to_apex  = "wwwToApex"

  # --- WAF ---
  waf_security_policy  = "sp-${var.project}-${var.environment}"
  waf_rate_limit_name  = "ratelimitperip"
  waf_rate_limit_count = 100 # requests per minute per client IP

  # --- Observability ---
  # Diagnostic settings are sub-resources of their target (same
  # invisible-in-cost-reports reasoning as the FD child names above),
  # so they stay descriptive rather than CAF-patterned.
  diag_frontdoor_name = "diag-frontdoor-to-law"
  diag_blob_name      = "diag-blob-to-law"
}
