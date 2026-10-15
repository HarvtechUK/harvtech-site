output "resource_group_name" {
  description = "Resource group holding the portal platform."
  value       = module.resource_group.name
}

output "container_registry_login_server" {
  description = "ACR login server (e.g. crharvtechportalprduks01.azurecr.io) — the deploy workflow pushes the image here."
  value       = module.container_registry.login_server
}

output "container_registry_name" {
  description = "Container Registry name."
  value       = module.container_registry.name
}

output "container_app_name" {
  description = "Container App name — the deploy workflow updates its image to ship a release."
  value       = module.container_app.name
}

output "container_app_fqdn" {
  description = "Public ingress hostname of the Container App. The dns/ stack points portal.harvtech.co.uk at this (Phase 1.5)."
  value       = module.container_app.fqdn
}

output "cosmos_account_name" {
  description = "Portal Cosmos account name."
  value       = azurerm_cosmosdb_account.portal.name
}

output "cosmos_endpoint" {
  description = "Portal Cosmos endpoint (not a secret — access is via Entra RBAC, no keys)."
  value       = azurerm_cosmosdb_account.portal.endpoint
}

output "key_vault_name" {
  description = "Portal Key Vault name. Operators set secret values here when rotating (az keyvault secret set --vault-name …)."
  value       = module.key_vault.name
}
