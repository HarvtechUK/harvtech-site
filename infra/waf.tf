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
resource "azurerm_cdn_frontdoor_firewall_policy" "this" {
  name                = local.waf_policy_name
  resource_group_name = azurerm_resource_group.site.name
  sku_name            = azurerm_cdn_frontdoor_profile.this.sku_name
  enabled             = true
  mode                = "Prevention"

  # Block WordPress / PHP scans. The site is static HTML — there is no
  # /wp-admin, no PHP. Any request matching these is a scanner.
  custom_rule {
    name     = "blockWordPressAndPhpScans"
    enabled  = true
    priority = 10
    type     = "MatchRule"
    action   = "Block"

    match_condition {
      match_variable     = "RequestUri"
      operator           = "Contains"
      negation_condition = false
      transforms         = ["Lowercase"]
      match_values = [
        "/wp-admin",
        "/wp-login",
        "/wp-content",
        "/wp-includes",
        "/xmlrpc.php",
        ".php",
      ]
    }
  }

  # Block obvious leaked-secret/source-control probes.
  custom_rule {
    name     = "blockDotfileAndVcsProbes"
    enabled  = true
    priority = 20
    type     = "MatchRule"
    action   = "Block"

    match_condition {
      match_variable     = "RequestUri"
      operator           = "Contains"
      negation_condition = false
      transforms         = ["Lowercase"]
      match_values = [
        "/.env",
        "/.git",
        "/.aws",
        "/.ssh",
        "/config.json",
        "/credentials",
      ]
    }
  }

  # Block common admin-panel discovery paths the static site doesn't serve.
  custom_rule {
    name     = "blockAdminPanelProbes"
    enabled  = true
    priority = 30
    type     = "MatchRule"
    action   = "Block"

    match_condition {
      match_variable     = "RequestUri"
      operator           = "Contains"
      negation_condition = false
      transforms         = ["Lowercase"]
      match_values = [
        "/phpmyadmin",
        "/adminer",
        "/manager/html",
        "/server-status",
        "/server-info",
      ]
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

# Binds the WAF policy to the custom domains on this profile.
resource "azurerm_cdn_frontdoor_security_policy" "this" {
  name                     = local.waf_security_policy
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.this.id

      association {
        patterns_to_match = ["/*"]

        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.apex.id
        }

        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_custom_domain.www.id
        }
      }
    }
  }
}
