output "id" {
  description = "Container app ID."
  value       = azurerm_container_app.workload.id
}

output "name" {
  description = "Container app name, for az containerapp calls."
  value       = azurerm_container_app.workload.name
}

output "fqdn" {
  description = "Ingress hostname. Public only when external_ingress_enabled is true."
  value       = azurerm_container_app.workload.ingress[0].fqdn
}

output "principal_id" {
  description = "Object ID of the system-assigned identity, for granting AcrPull, Key Vault Secrets User and data-plane roles."
  value       = azurerm_container_app.workload.identity[0].principal_id
}

output "latest_revision_name" {
  description = "Most recent revision, useful for deployment checks."
  value       = azurerm_container_app.workload.latest_revision_name
}

output "outbound_ip_addresses" {
  description = "Outbound IPs, for allow-listing the app at a downstream firewall."
  value       = azurerm_container_app.workload.outbound_ip_addresses
}
