# Log Analytics workspace + diagnostic settings for the site stack.
#
# Two jobs in one:
#   1. Visitor analytics without client-side JavaScript. Front Door
#      already sees every request at the edge (path, referrer, user
#      agent, client IP) — shipping its access log to Log Analytics
#      gives page-view and unique-visitor reporting via KQL with zero
#      cookies, zero tracking scripts, and no consent banner. The
#      saved searches below are the "reports". The privacy policy
#      (site/src/pages/privacy.astro) describes this processing and
#      its 30-day retention — keep the two in sync.
#   2. Closes the deferred storage-logging findings (Trivy AZU-0057,
#      Checkov CKV_AZURE_33 / CKV2_AZURE_21): blob-service activity on
#      the $web origin now lands in the same workspace. See
#      .trivyignore / .checkov.yaml for where each was tracked.
#
# Cost: PerGB2018 has no base charge — ingestion is pay-per-GB
# (~£2.30/GB) with the first 31 days of interactive retention
# included. This site's logs are tens of MB/month, so the realistic
# bill is pennies. The 1 GB/day cap bounds a log-flood at ~£2.30/day
# (trade-off: if the cap trips, ingestion stops for the rest of the
# day — acceptable here, the WAF rate limit throttles the obvious
# sources long before the cap).
resource "azurerm_log_analytics_workspace" "site" {
  name                = local.law_name
  location            = azurerm_resource_group.site.location
  resource_group_name = azurerm_resource_group.site.name
  sku                 = "PerGB2018"
  retention_in_days   = 30 # privacy policy promises deletion after 30 days
  daily_quota_gb      = 1
  tags                = module.tags.tags
}

# Front Door: access log (the analytics feed) + WAF log (what got
# blocked and why — closes the loop on the custom rules in waf.tf).
# Health-probe log omitted deliberately: probe failures already
# surface via the OriginHealthPercentage metric and add nothing to
# either the analytics or the audit story.
resource "azurerm_monitor_diagnostic_setting" "frontdoor" {
  name                       = local.diag_frontdoor_name
  target_resource_id         = azurerm_cdn_frontdoor_profile.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.site.id

  enabled_log {
    category = "FrontDoorAccessLog"
  }

  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"
  }
}

# Blob service of the $web origin. Mostly redundant with the FD access
# log for traffic analysis (only cache misses reach the origin), but
# this is the control the deferred storage-logging findings actually
# ask for: an audit trail of every read/write/delete against the
# origin — including requests that bypass Front Door and hit
# *.web.core.windows.net directly, which the FD log can never see.
resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name                       = local.diag_blob_name
  target_resource_id         = "${azurerm_storage_account.site.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.site.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }
}

# --- Saved searches: the "analytics dashboard" ------------------------
#
# Front Door diagnostics land in the shared AzureDiagnostics table,
# whose columns carry auto-schema type suffixes (_s string, _d double).
# `dcount(client IP + user agent)` is the standard cookieless
# approximation of unique visitors — the same technique Plausible and
# Fathom use, minus the client-side script. The page-view queries drop
# asset requests (anything with a file extension) and the obvious
# crawler user agents; the numbers are honest approximations, not
# product-analytics precision.

resource "azurerm_log_analytics_saved_search" "page_views_daily" {
  name                       = "HarvTechPageViewsDaily"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.site.id
  category                   = "Site analytics"
  display_name               = "Page views and unique visitors by day (30d)"
  query                      = <<-KQL
    AzureDiagnostics
    | where Category == "FrontDoorAccessLog" and TimeGenerated > ago(30d)
    | extend path = tostring(parse_url(requestUri_s).Path)
    | where path == "/" or path !contains "."
    | where userAgent_s !has "bot" and userAgent_s !has "crawl" and userAgent_s !has "spider"
    | summarize pageViews = count(), uniqueVisitors = dcount(strcat(clientIp_s, userAgent_s)) by bin(TimeGenerated, 1d)
    | order by TimeGenerated asc
  KQL
}

resource "azurerm_log_analytics_saved_search" "top_pages" {
  name                       = "HarvTechTopPages"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.site.id
  category                   = "Site analytics"
  display_name               = "Top pages (14d)"
  query                      = <<-KQL
    AzureDiagnostics
    | where Category == "FrontDoorAccessLog" and TimeGenerated > ago(14d)
    | extend path = tostring(parse_url(requestUri_s).Path)
    | where path == "/" or path !contains "."
    | where userAgent_s !has "bot" and userAgent_s !has "crawl" and userAgent_s !has "spider"
    | summarize pageViews = count(), uniqueVisitors = dcount(strcat(clientIp_s, userAgent_s)) by path
    | order by pageViews desc
  KQL
}

resource "azurerm_log_analytics_saved_search" "top_referrers" {
  name                       = "HarvTechTopReferrers"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.site.id
  category                   = "Site analytics"
  display_name               = "Top external referrers (14d)"
  query                      = <<-KQL
    AzureDiagnostics
    | where Category == "FrontDoorAccessLog" and TimeGenerated > ago(14d)
    | extend referrerHost = tostring(parse_url(referer_s).Host)
    | where isnotempty(referrerHost) and referrerHost !endswith "harvtech.co.uk"
    | summarize visits = count() by referrerHost
    | order by visits desc
  KQL
}

resource "azurerm_log_analytics_saved_search" "waf_blocks" {
  name                       = "HarvTechWafBlocks"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.site.id
  category                   = "Site analytics"
  display_name               = "WAF blocks by rule and day (7d)"
  query                      = <<-KQL
    AzureDiagnostics
    | where Category == "FrontDoorWebApplicationFirewallLog" and TimeGenerated > ago(7d)
    | where action_s == "Block"
    | summarize blocks = count() by ruleName_s, bin(TimeGenerated, 1d)
    | order by TimeGenerated desc
  KQL
}
