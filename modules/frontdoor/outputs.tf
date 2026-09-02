output "profile_id" {
  description = "Resource ID of the Front Door profile."
  value       = azurerm_cdn_frontdoor_profile.delivery.id
}

output "endpoint_id" {
  description = "Resource ID of the endpoint — usable as a DNS alias target (A record target_resource_id)."
  value       = azurerm_cdn_frontdoor_endpoint.delivery.id
}

output "endpoint_hostname" {
  description = "The *.azurefd.net hostname of the endpoint — CNAME target for custom domains."
  value       = azurerm_cdn_frontdoor_endpoint.delivery.host_name
}

output "custom_domain_ids" {
  description = "Resource IDs of the custom domains, keyed by var.custom_domains key."
  value       = { for k, cd in azurerm_cdn_frontdoor_custom_domain.domain : k => cd.id }
}

output "custom_domain_validation_tokens" {
  description = "TXT values to publish at _dnsauth.<host> for domain validation, keyed by var.custom_domains key."
  value       = { for k, cd in azurerm_cdn_frontdoor_custom_domain.domain : k => cd.validation_token }
  sensitive   = true
}
