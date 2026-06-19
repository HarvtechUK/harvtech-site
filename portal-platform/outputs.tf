output "resource_group_name" {
  description = "Resource group holding the portal platform."
  value       = azurerm_resource_group.this.name
}

output "static_web_app_default_hostname" {
  description = "SWA default hostname (*.azurestaticapps.net). The dns/ stack points the portal CNAME at this."
  value       = azurerm_static_web_app.portal.default_host_name
}

output "static_web_app_id" {
  description = "Resource ID of the Static Web App."
  value       = azurerm_static_web_app.portal.id
}

output "function_app_name" {
  description = "Function App name (the portal API)."
  value       = azurerm_linux_function_app.api.name
}

output "function_app_default_hostname" {
  description = "Function App default hostname."
  value       = azurerm_linux_function_app.api.default_hostname
}

output "cosmos_account_name" {
  description = "Portal Cosmos account name."
  value       = azurerm_cosmosdb_account.this.name
}

output "cosmos_endpoint" {
  description = "Portal Cosmos endpoint (not a secret — access is via Entra RBAC, no keys)."
  value       = azurerm_cosmosdb_account.this.endpoint
}
