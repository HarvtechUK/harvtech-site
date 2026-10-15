output "id" {
  description = "Storage account ID, for scoping role assignments and diagnostic settings."
  value       = azurerm_storage_account.workload.id
}

output "name" {
  description = "Storage account name, for CLI and SDK calls (for example az storage blob upload-batch)."
  value       = azurerm_storage_account.workload.name
}

output "primary_blob_endpoint" {
  description = "Blob service endpoint (https://<name>.blob.core.windows.net/)."
  value       = azurerm_storage_account.workload.primary_blob_endpoint
}

output "primary_dfs_endpoint" {
  description = "Data Lake (dfs) endpoint. Meaningful when hierarchical_namespace_enabled is true."
  value       = azurerm_storage_account.workload.primary_dfs_endpoint
}

output "primary_web_endpoint" {
  description = "Static website endpoint URL, or null when static_website is not configured."
  value       = var.static_website == null ? null : azurerm_storage_account.workload.primary_web_endpoint
}

output "primary_web_host" {
  description = "Static website hostname (no scheme), for a CDN or Front Door origin. null when static_website is not configured."
  value       = var.static_website == null ? null : azurerm_storage_account.workload.primary_web_host
}

output "container_ids" {
  description = "Container IDs keyed by container name."
  value       = { for name, container in azurerm_storage_container.workload : name => container.id }
}

output "role_assignment_ids" {
  description = "Role assignment IDs keyed the same way as var.role_assignments."
  value       = { for key, assignment in azurerm_role_assignment.workload : key => assignment.id }
}
