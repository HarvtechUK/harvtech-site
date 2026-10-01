# State moves for the modules/frontdoor extraction (and the older
# per-domain → for_each migration before it). Every Front Door resource
# keeps its Azure identity — the adoption plan must show 0 to add,
# 0 to destroy. Without these blocks Terraform would tear down the live
# Front Door and re-create it inside the module, taking the site down
# and re-triggering domain validation.
#
# The first two hops predate the module (the old per-domain resources
# → the for_each map). Terraform chains them with the module hops below,
# so state at ANY historical address resolves to the module address.

moved {
  from = azurerm_cdn_frontdoor_custom_domain.apex
  to   = azurerm_cdn_frontdoor_custom_domain.this["apex"]
}

moved {
  from = azurerm_cdn_frontdoor_custom_domain.www
  to   = azurerm_cdn_frontdoor_custom_domain.this["www"]
}

moved {
  from = azurerm_cdn_frontdoor_custom_domain_association.apex
  to   = azurerm_cdn_frontdoor_custom_domain_association.this["apex"]
}

moved {
  from = azurerm_cdn_frontdoor_custom_domain_association.www
  to   = azurerm_cdn_frontdoor_custom_domain_association.this["www"]
}

# --- Root → modules/frontdoor (the module extraction) ---
# Labels also change from the old generic "this" to role-based names.

moved {
  from = azurerm_cdn_frontdoor_profile.this
  to   = module.frontdoor.azurerm_cdn_frontdoor_profile.delivery
}

moved {
  from = azurerm_cdn_frontdoor_endpoint.this
  to   = module.frontdoor.azurerm_cdn_frontdoor_endpoint.delivery
}

moved {
  from = azurerm_cdn_frontdoor_origin_group.site
  to   = module.frontdoor.azurerm_cdn_frontdoor_origin_group.primary
}

moved {
  from = azurerm_cdn_frontdoor_origin.storage_web
  to   = module.frontdoor.azurerm_cdn_frontdoor_origin.primary
}

# Moving the whole for_each collection moves every instance (apex, www, …).
moved {
  from = azurerm_cdn_frontdoor_custom_domain.this
  to   = module.frontdoor.azurerm_cdn_frontdoor_custom_domain.domain
}

# In the module the redirect is optional (count), so the single resources
# land at index [0].
moved {
  from = azurerm_cdn_frontdoor_rule_set.apex
  to   = module.frontdoor.azurerm_cdn_frontdoor_rule_set.redirects[0]
}

moved {
  from = azurerm_cdn_frontdoor_rule.www_to_apex
  to   = module.frontdoor.azurerm_cdn_frontdoor_rule.www_to_apex[0]
}

moved {
  from = azurerm_cdn_frontdoor_route.default
  to   = module.frontdoor.azurerm_cdn_frontdoor_route.default
}

moved {
  from = azurerm_cdn_frontdoor_custom_domain_association.this
  to   = module.frontdoor.azurerm_cdn_frontdoor_custom_domain_association.domain
}

moved {
  from = azurerm_cdn_frontdoor_firewall_policy.this
  to   = module.frontdoor.azurerm_cdn_frontdoor_firewall_policy.waf
}

moved {
  from = azurerm_cdn_frontdoor_security_policy.this
  to   = module.frontdoor.azurerm_cdn_frontdoor_security_policy.waf
}
