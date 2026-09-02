# frontdoor

An opinionated Azure Front Door: profile, endpoint, one origin group and
origin, custom domains with managed certificates, a catch-all HTTPS
route, an optional www→apex 301, and a WAF **that is not optional** —
this module refuses to build an unprotected Front Door. Every instance
gets a firewall policy (path block-rules + a per-IP rate limit) bound to
all of its custom domains.

## Usage

```hcl
module "frontdoor" {
  source              = "../modules/frontdoor"
  resource_group_name = azurerm_resource_group.site.name

  profile_name      = module.naming.cdn_frontdoor_profile
  endpoint_name     = "harvtech"
  origin_group_name = "og-site"
  origin_name       = "origin-storage-web"
  origin_host_name  = azurerm_storage_account.site.primary_web_host
  route_name        = "route-default"

  custom_domains = {
    apex = { host_name = "example.co.uk", name = "example-co-uk" }
    www  = { host_name = "www.example.co.uk", name = "www-example-co-uk" }
  }

  www_to_apex_redirect = {
    rule_set_name = "rsapex"
    rule_name     = "wwwToApex"
    www_hostname  = "www.example.co.uk"
    apex_hostname = "example.co.uk"
  }

  waf_policy_name          = module.naming.cdn_frontdoor_firewall_policy
  waf_security_policy_name = "sp-example-prd"
  waf_block_rules          = var.waf_block_rules
  waf_rate_limit           = { name = "ratelimitperip", threshold = 100 }

  tags = module.tags.tags
}
```

## Opinions baked in

- **WAF always on**, bound to every custom domain automatically —
  adding a domain extends coverage without remembering a second step.
  `waf_mode = "Detection"` is the escape hatch for false positives.
- **HTTPS only**: the route redirects HTTP and forwards HttpsOnly;
  custom-domain TLS is managed certificates at TLS 1.2 minimum.
- **Standard SKU by default** — custom WAF rules only. Managed rulesets
  (OWASP DRS / Bot Manager) and Private Link to origin need
  `sku_name = "Premium_AzureFrontDoor"` (~£200/mo uplift).
- Custom-domain **map keys are Terraform addresses** — keep them stable
  or the domain recreates and re-triggers validation.

## Outputs

`endpoint_id` / `endpoint_hostname` feed DNS (alias A record at the
apex, CNAME for subdomains); `custom_domain_validation_tokens` feeds
the `_dnsauth` TXT records. See `dns/site_records.tf` for the consuming
end of that dance.

## Adopting without downtime

This module was extracted from live root-module resources. If you're
doing the same, `moved` blocks in the root map every old address to its
new `module.frontdoor.…` address — the adoption plan must show
**0 to add, 0 to destroy**. See `infra/moves.tf`.
