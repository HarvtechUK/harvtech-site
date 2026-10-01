# Front Door delivery: profile → endpoint → origin group/origin →
# custom domains → route. WAF lives in waf.tf and is always attached.
#
# On Standard SKU, WAF is limited to custom rules; Microsoft-managed
# rulesets (DRS and BotManager) require Premium. See waf.tf for the
# practical workaround using targeted custom rules.

resource "azurerm_cdn_frontdoor_profile" "delivery" {
  name                = var.profile_name
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "delivery" {
  name                     = var.endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.delivery.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "primary" {
  name                     = var.origin_group_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.delivery.id
  session_affinity_enabled = false

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10

  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Https"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "primary" {
  name                          = var.origin_name
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.primary.id

  enabled                        = true
  certificate_name_check_enabled = true

  host_name          = var.origin_host_name
  origin_host_header = var.origin_host_name
  http_port          = 80
  https_port         = 443
  priority           = 1
  weight             = 1000
}

# --- Custom domains ---
# The map key (apex / www / …) is the Terraform address suffix — keep it
# stable across renames or the domain is destroyed and re-created, which
# re-triggers the validation TXT dance.
resource "azurerm_cdn_frontdoor_custom_domain" "domain" {
  for_each = var.custom_domains

  name                     = each.value.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.delivery.id
  host_name                = each.value.host_name

  tls {
    certificate_type = "ManagedCertificate"
    minimum_version  = "TLS12"
  }
}

# --- Rules engine: www -> apex (301), created only when configured ---
resource "azurerm_cdn_frontdoor_rule_set" "redirects" {
  count = var.www_to_apex_redirect == null ? 0 : 1

  name                     = var.www_to_apex_redirect.rule_set_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.delivery.id
}

resource "azurerm_cdn_frontdoor_rule" "www_to_apex" {
  count = var.www_to_apex_redirect == null ? 0 : 1

  name                      = var.www_to_apex_redirect.rule_name
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.redirects[0].id
  order                     = 1
  behavior_on_match         = "Stop"

  conditions {
    host_name_condition {
      operator         = "Equal"
      match_values     = [var.www_to_apex_redirect.www_hostname]
      negate_condition = false
      transforms       = ["Lowercase"]
    }
  }

  actions {
    url_redirect_action {
      redirect_type        = "Moved" # 301
      redirect_protocol    = "Https"
      destination_hostname = var.www_to_apex_redirect.apex_hostname
      destination_path     = ""
      query_string         = ""
      destination_fragment = ""
    }
  }
}

# --- Route binding everything together ---
resource "azurerm_cdn_frontdoor_route" "default" {
  name                          = var.route_name
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.delivery.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.primary.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.primary.id]
  # Splat over the conditional rule set: [] when no redirect, [id] when on.
  cdn_frontdoor_rule_set_ids = azurerm_cdn_frontdoor_rule_set.redirects[*].id

  enabled                = true
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  cdn_frontdoor_custom_domain_ids = [
    for cd in azurerm_cdn_frontdoor_custom_domain.domain : cd.id
  ]
  link_to_default_domain = true
}

# --- Associate custom domains with the route ---
# Required for Azure to consider the domain "in use" on this route.
resource "azurerm_cdn_frontdoor_custom_domain_association" "domain" {
  for_each = var.custom_domains

  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.domain[each.key].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.default.id]
}
