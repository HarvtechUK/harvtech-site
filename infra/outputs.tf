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
# Names are part of the cross-stack contract with dns/ — keep them
# stable even though the values now come from modules/frontdoor.

output "frontdoor_endpoint_hostname" {
  value       = module.frontdoor.endpoint_hostname
  description = "Front Door endpoint FQDN (the *.azurefd.net hostname)"
}

output "frontdoor_endpoint_id" {
  value       = module.frontdoor.endpoint_id
  description = "Resource ID of the Front Door endpoint (used as DNS alias target)"
}

# Per-domain validation tokens kept as individually-named outputs so
# the dns/ stack's terraform_remote_state references don't have to
# learn about the map shape.
output "apex_validation_token" {
  value       = module.frontdoor.custom_domain_validation_tokens["apex"]
  description = "TXT value to publish at _dnsauth.harvtech.co.uk for domain validation"
  sensitive   = true
}

output "www_validation_token" {
  value       = module.frontdoor.custom_domain_validation_tokens["www"]
  description = "TXT value to publish at _dnsauth.www.harvtech.co.uk for domain validation"
  sensitive   = true
}

# Generic map output too — lets future domains expose their tokens
# automatically without adding more per-domain outputs above.
output "custom_domain_validation_tokens" {
  value       = module.frontdoor.custom_domain_validation_tokens
  description = "Validation tokens for every custom domain managed here, keyed by var.custom_domains key."
  sensitive   = true
}
