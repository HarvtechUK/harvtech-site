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
