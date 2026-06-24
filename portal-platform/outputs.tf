output "resource_group_name" {
  description = "Resource group holding the portal platform."
  value       = azurerm_resource_group.portal.name
}

output "container_registry_login_server" {
  description = "ACR login server (e.g. crharvtechportalprduks01.azurecr.io) — the deploy workflow pushes the image here."
  value       = azurerm_container_registry.portal.login_server
}

output "container_registry_name" {
  description = "Container Registry name."
  value       = azurerm_container_registry.portal.name
}

output "container_app_name" {
  description = "Container App name — the deploy workflow updates its image to ship a release."
  value       = azurerm_container_app.portal.name
}

output "container_app_fqdn" {
  description = "Public ingress hostname of the Container App. The dns/ stack points portal.harvtech.co.uk at this (Phase 1.5)."
  value       = azurerm_container_app.portal.ingress[0].fqdn
}

output "cosmos_account_name" {
  description = "Portal Cosmos account name."
  value       = azurerm_cosmosdb_account.portal.name
}

output "cosmos_endpoint" {
  description = "Portal Cosmos endpoint (not a secret — access is via Entra RBAC, no keys)."
  value       = azurerm_cosmosdb_account.portal.endpoint
}
