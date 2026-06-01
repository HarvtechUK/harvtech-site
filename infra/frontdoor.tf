# Front Door Standard profile. On Standard, WAF is limited to custom rules;
# Microsoft-managed rulesets (DRS and BotManager) require Premium. See waf.tf
# for the practical workaround using targeted custom rules.
resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = local.fd_profile_name
  resource_group_name = azurerm_resource_group.site.name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = local.fd_endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "site" {
  name                     = local.fd_origin_group_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
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

# Origin = the static-website endpoint of the storage account.
resource "azurerm_cdn_frontdoor_origin" "storage_web" {
  name                          = local.fd_origin_name
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.site.id

  enabled                        = true
  certificate_name_check_enabled = true

  host_name          = azurerm_storage_account.site.primary_web_host
  origin_host_header = azurerm_storage_account.site.primary_web_host
  http_port          = 80
  https_port         = 443
  priority           = 1
  weight             = 1000
}

# --- Custom domains ---
# Iterated over var.custom_domains (defined in terraform.tfvars) so adding
# a new domain is a one-line tfvars edit, not a new resource block. The
# map key (apex / www / ...) is the Terraform address suffix and must
# stay stable across renames or the custom domain will be destroyed and
# re-created — which would re-trigger the FD validation TXT dance.
resource "azurerm_cdn_frontdoor_custom_domain" "this" {
  for_each = var.custom_domains

  name                     = each.value.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  host_name                = each.value.host_name

  tls {
    certificate_type = "ManagedCertificate"
    minimum_version  = "TLS12"
  }
}

# `moved` blocks preserve the existing state addresses across the rename
# from the old per-domain resources to the for_each map. Without these,
# Terraform would plan a destroy-and-recreate for both domains.
moved {
  from = azurerm_cdn_frontdoor_custom_domain.apex
  to   = azurerm_cdn_frontdoor_custom_domain.this["apex"]
}
moved {
  from = azurerm_cdn_frontdoor_custom_domain.www
  to   = azurerm_cdn_frontdoor_custom_domain.this["www"]
}

# --- Rules engine: www -> apex (301 redirect) ---
resource "azurerm_cdn_frontdoor_rule_set" "apex" {
  name                     = local.fd_rule_set_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
}

resource "azurerm_cdn_frontdoor_rule" "www_to_apex" {
  name                      = local.fd_rule_www_to_apex
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.apex.id
  order                     = 1
  behavior_on_match         = "Stop"

  conditions {
    host_name_condition {
      operator         = "Equal"
      match_values     = [local.www_domain]
      negate_condition = false
      transforms       = ["Lowercase"]
    }
  }

  actions {
    url_redirect_action {
      redirect_type        = "Moved" # 301
      redirect_protocol    = "Https"
      destination_hostname = local.apex_domain
      destination_path     = ""
      query_string         = ""
      destination_fragment = ""
    }
  }
}

# --- Route binding everything together ---
resource "azurerm_cdn_frontdoor_route" "default" {
  name                          = local.fd_route_name
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.site.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.storage_web.id]
  cdn_frontdoor_rule_set_ids    = [azurerm_cdn_frontdoor_rule_set.apex.id]

  enabled                = true
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  cdn_frontdoor_custom_domain_ids = [
    for cd in azurerm_cdn_frontdoor_custom_domain.this : cd.id
  ]
  link_to_default_domain = true
}

# --- Associate custom domains with the route ---
# Required for Azure to consider the domain "in use" on this route.
# Same for_each + map key pattern as the custom_domain resources above.
resource "azurerm_cdn_frontdoor_custom_domain_association" "this" {
  for_each = var.custom_domains

  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.this[each.key].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.default.id]
}

moved {
  from = azurerm_cdn_frontdoor_custom_domain_association.apex
  to   = azurerm_cdn_frontdoor_custom_domain_association.this["apex"]
}
moved {
  from = azurerm_cdn_frontdoor_custom_domain_association.www
  to   = azurerm_cdn_frontdoor_custom_domain_association.this["www"]
}
