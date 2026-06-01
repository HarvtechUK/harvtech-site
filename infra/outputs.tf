output "storage_account_name" {
  value       = azurerm_storage_account.site.name
  description = "Storage account hosting the static site"
}

output "primary_web_endpoint" {
  value       = azurerm_storage_account.site.primary_web_endpoint
  description = "Public URL of the static site (before custom domain)"
}

output "resource_group_name" {
  value = azurerm_resource_group.site.name
}

# --- Front Door outputs (consumed by dns/ via terraform_remote_state) ---

output "frontdoor_endpoint_hostname" {
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
  description = "Front Door endpoint FQDN (the *.azurefd.net hostname)"
}

output "frontdoor_endpoint_id" {
  value       = azurerm_cdn_frontdoor_endpoint.this.id
  description = "Resource ID of the Front Door endpoint (used as DNS alias target)"
}

# Per-domain validation tokens kept as individually-named outputs so
# the dns/ stack's terraform_remote_state references don't have to
# learn about the for_each map shape. Read directly from the loop.
output "apex_validation_token" {
  value       = azurerm_cdn_frontdoor_custom_domain.this["apex"].validation_token
  description = "TXT value to publish at _dnsauth.harvtech.co.uk for domain validation"
  sensitive   = true
}

output "www_validation_token" {
  value       = azurerm_cdn_frontdoor_custom_domain.this["www"].validation_token
  description = "TXT value to publish at _dnsauth.www.harvtech.co.uk for domain validation"
  sensitive   = true
}

# Generic map output too — lets future domains expose their tokens
# automatically without adding more per-domain outputs above.
output "custom_domain_validation_tokens" {
  value = {
    for k, cd in azurerm_cdn_frontdoor_custom_domain.this : k => cd.validation_token
  }
  description = "Validation tokens for every custom domain managed here, keyed by var.custom_domains key."
  sensitive   = true
}
