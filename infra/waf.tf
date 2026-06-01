# Front Door WAF policy.
#
# SKU note: this profile is Standard_AzureFrontDoor. On Standard, only custom
# rules are available — Microsoft_DefaultRuleSet (OWASP DRS) and
# Microsoft_BotManagerRuleSet require Premium_AzureFrontDoor (~£200/mo
# uplift). For a portfolio site that cost wasn't justified; the rules below
# cover the common attack patterns we actually see in logs (WordPress probes,
# PHP scans, env/git leaks) plus a per-IP rate limit. Upgrade path to Premium
# is documented in the README.
#
# Mode: Prevention. Toggle to "Detection" if a deploy triggers false
# positives; rerunning apply with `mode = "Detection"` is a fast escape hatch.
#
# Structure:
#   - "Block path" rules (WordPress, dotfile, admin-panel) iterate
#     var.waf_block_rules via a dynamic block. Same shape across all three,
#     so adding a fourth category is a one-line tfvars edit.
#   - Rate-limit rule has a different shape (RateLimitRule type, threshold
#     fields) so it stays as its own static custom_rule block.
resource "azurerm_cdn_frontdoor_firewall_policy" "this" {
  name                = local.waf_policy_name
  resource_group_name = azurerm_resource_group.site.name
  sku_name            = azurerm_cdn_frontdoor_profile.this.sku_name
  enabled             = true
  mode                = "Prevention"

  # Iterates var.waf_block_rules (defined in prd.tfvars). Each entry
  # has a name, priority, and a list of substrings to block on in
  # the RequestUri. Adding a new probe category = one new list entry.
  #
  # for_each over the list (not a map) preserves the tfvars ordering,
  # which keeps Terraform's plan diff stable — converting to a
  # map-by-name would alphabetise, churning the rendered position of
  # each rule even though Azure evaluates by `priority` not order.
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

  # Rate limit: 100 req/min per client IP. Hard for a real human to hit,
  # cheap enough that simple scrapers / brute-forcers get throttled.
  custom_rule {
    name                           = local.waf_rate_limit_name
    enabled                        = true
    priority                       = 100
    type                           = "RateLimitRule"
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = local.waf_rate_limit_count
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

# Binds the WAF policy to every custom domain in var.custom_domains via
# a dynamic block — adding a new domain to the tfvars map automatically
# extends WAF coverage to it. No need to remember to update this file too.
resource "azurerm_cdn_frontdoor_security_policy" "this" {
  name                     = local.waf_security_policy
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.this.id

      association {
        patterns_to_match = ["/*"]

        dynamic "domain" {
          for_each = azurerm_cdn_frontdoor_custom_domain.this
          content {
            cdn_frontdoor_domain_id = domain.value.id
          }
        }
      }
    }
  }
}
