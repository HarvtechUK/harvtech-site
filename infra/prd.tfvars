# Auto-loaded by Terraform on plan / apply. Holds the data-shape inputs
# that drive the for_each loops in waf.tf and frontdoor.tf — keeping
# them here (rather than as defaults in variables.tf) means scaling out
# is purely a tfvars edit, no resource code changed.

# --- Custom domains ---
# Adding another domain (e.g. cv.harvtech.co.uk) = one new map entry.
# The map key is what shows up as the Terraform address suffix
# (azurerm_cdn_frontdoor_custom_domain.this["apex"]); keep it stable
# once published or you'll force re-validation.
custom_domains = {
  apex = {
    host_name = "harvtech.co.uk"
    name      = "harvtech-co-uk"
  }
  www = {
    host_name = "www.harvtech.co.uk"
    name      = "www-harvtech-co-uk"
  }
}

# --- WAF "block path" custom rules ---
# All three originally-separate rules have the same shape:
#   "is this path in a list of strings? if so, block."
# Collapsed into a single dynamic block iterating this list. To add a
# new category of probe (e.g. ".git/HEAD", "/cgi-bin"), append a map
# entry — no Terraform code change needed.
waf_block_rules = [
  {
    name        = "blockWordPressAndPhpScans"
    priority    = 10
    description = "Block WordPress / PHP scans — the site is static HTML"
    match_values = [
      "/wp-admin",
      "/wp-login",
      "/wp-content",
      "/wp-includes",
      "/xmlrpc.php",
      ".php",
    ]
  },
  {
    name        = "blockDotfileAndVcsProbes"
    priority    = 20
    description = "Block leaked-secret / source-control probes"
    match_values = [
      "/.env",
      "/.git",
      "/.aws",
      "/.ssh",
      "/config.json",
      "/credentials",
    ]
  },
  {
    name        = "blockAdminPanelProbes"
    priority    = 30
    description = "Block common admin-panel discovery paths"
    match_values = [
      "/phpmyadmin",
      "/adminer",
      "/manager/html",
      "/server-status",
      "/server-info",
    ]
  },
]
