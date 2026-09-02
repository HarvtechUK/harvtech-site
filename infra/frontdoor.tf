# Front Door + WAF for the static site — the composition lives in
# modules/frontdoor (profile, endpoint, origin, custom domains, route,
# www→apex redirect, and an always-on WAF bound to every domain).
# This stack supplies the site-specific values; moves.tf holds the
# moved blocks from the pre-module resource addresses.
module "frontdoor" {
  source = "../modules/frontdoor"

  resource_group_name = azurerm_resource_group.site.name

  profile_name      = local.fd_profile_name
  endpoint_name     = local.fd_endpoint_name
  origin_group_name = local.fd_origin_group_name
  origin_name       = local.fd_origin_name
  origin_host_name  = azurerm_storage_account.site.primary_web_host
  route_name        = local.fd_route_name

  custom_domains = var.custom_domains

  www_to_apex_redirect = {
    rule_set_name = local.fd_rule_set_name
    rule_name     = local.fd_rule_www_to_apex
    www_hostname  = local.www_domain
    apex_hostname = local.apex_domain
  }

  waf_policy_name          = local.waf_policy_name
  waf_security_policy_name = local.waf_security_policy
  waf_block_rules          = var.waf_block_rules
  waf_rate_limit = {
    name      = local.waf_rate_limit_name
    threshold = local.waf_rate_limit_count
  }

  tags = module.tags.tags
}
