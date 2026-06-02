output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "RG holding the data-platform resources."
}

output "datalake_name" {
  value       = azurerm_storage_account.datalake.name
  description = "ADLS Gen2 storage account name."
}

output "datalake_dfs_endpoint" {
  value       = azurerm_storage_account.datalake.primary_dfs_endpoint
  description = "ADLS Gen2 DFS endpoint (the abfss://-style hostname). What Spark / Databricks would use to read."
}

output "cosmos_endpoint" {
  value       = azurerm_cosmosdb_account.this.endpoint
  description = "Cosmos account endpoint URL."
}

output "cosmos_free_tier_enabled" {
  value       = azurerm_cosmosdb_account.this.free_tier_enabled
  description = "Whether the Cosmos free-tier discount is active on this account."
}

output "adf_name" {
  value       = azurerm_data_factory.this.name
  description = "Data Factory name."
}

output "databricks_workspace_url" {
  value       = azurerm_databricks_workspace.this.workspace_url
  description = "Databricks workspace UI URL."
}

output "databricks_managed_resource_group" {
  value       = azurerm_databricks_workspace.this.managed_resource_group_name
  description = "RG Databricks created for itself (VMs, NSG, storage)."
}
