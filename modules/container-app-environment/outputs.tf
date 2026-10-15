output "id" {
  description = "Environment ID, for a container app's container_app_environment_id."
  value       = azurerm_container_app_environment.workload.id
}

output "name" {
  description = "Environment name."
  value       = azurerm_container_app_environment.workload.name
}

output "default_domain" {
  description = "Default domain (<random>.<region>.azurecontainerapps.io). An app's public hostname is \"<app name>.<default_domain>\", known before the app exists, which lets callers build redirect URIs without a dependency cycle."
  value       = azurerm_container_app_environment.workload.default_domain
}

output "static_ip_address" {
  description = "The environment's static IP: the inbound address with VNet integration, or the shared public address without."
  value       = azurerm_container_app_environment.workload.static_ip_address
}
