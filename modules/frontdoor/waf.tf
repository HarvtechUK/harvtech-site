# WAF policy — always created and always bound to every custom domain.
# This module deliberately won't build an unprotected Front Door.
#
# SKU note: on Standard, only custom rules are available —
# Microsoft_DefaultRuleSet (OWASP DRS) and Microsoft_BotManagerRuleSet
# require Premium (~£200/mo uplift). The block rules cover the common
# attack patterns actually seen in logs (WordPress probes, PHP scans,
# env/git leaks) plus a per-IP rate limit.
#
# Mode: Prevention by default. Flip var.waf_mode to "Detection" if a
# deploy triggers false positives — log-only, fast escape hatch.
resource "azurerm_cdn_frontdoor_firewall_policy" "waf" {
  name                = var.waf_policy_name
  resource_group_name = var.resource_group_name
  sku_name            = azurerm_cdn_frontdoor_profile.delivery.sku_name
  enabled             = true
  mode                = var.waf_mode

  # "Block this path" rules from var.waf_block_rules. for_each over the
  # list (not a map) preserves tfvars ordering, keeping the plan diff
  # stable — a map would alphabetise and churn rendered positions even
  # though Azure evaluates by priority.
  dynamic "custom_rule" {
    for_each = var.waf_block_rules
    content {
      name     = custom_rule.value.name
      enabled  = true
      priority = custom_rule.value.priority
      type     = "MatchRule"
      action   = "Block"

      match_condition {
        match_variable     = "RequestUri"
        operator           = "Contains"
        negation_condition = false
        transforms         = ["Lowercase"]
        match_values       = custom_rule.value.match_values
      }
    }
  }

  # Per-client-IP rate limit. The negated 0.0.0.0/0 match means "every
  # address" — the threshold does the real work.
  custom_rule {
    name                           = var.waf_rate_limit.name
    enabled                        = true
    priority                       = var.waf_rate_limit.priority
    type                           = "RateLimitRule"
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = var.waf_rate_limit.threshold
    action                         = "Block"

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "IPMatch"
      negation_condition = true
      match_values       = ["0.0.0.0/0"]
    }
  }

  tags = var.tags
}

# Bind the WAF to every custom domain — adding a domain to
# var.custom_domains automatically extends coverage to it.
resource "azurerm_cdn_frontdoor_security_policy" "waf" {
  name                     = var.waf_security_policy_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.delivery.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.waf.id

      association {
        patterns_to_match = ["/*"]

        dynamic "domain" {
          for_each = azurerm_cdn_frontdoor_custom_domain.domain
          content {
            cdn_frontdoor_domain_id = domain.value.id
          }
        }
      }
    }
  }
}
