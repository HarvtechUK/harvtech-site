# Azure Data Factory — orchestrator. Resource creation is free; cost
# only accrues when pipelines actually run (activity hours +
# integration-runtime hours + data-movement GB). Stub it without
# pipelines for now; future PRs can add datasets / linked services
# / pipelines as their own commits.
#
# SystemAssigned identity lets future pipelines authenticate to the
# datalake / Cosmos without storing connection strings — the same
# OIDC-flavoured discipline applied elsewhere in this repo.
resource "azurerm_data_factory" "this" {
  name                = local.adf_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  managed_virtual_network_enabled = false # public IR for cheap-demo simplicity
  public_network_enabled          = true

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Pre-grant ADF's managed identity Storage Blob Data Reader on the
# datalake so future pipelines reading from raw/cleansed/curated
# don't fail on first run while RBAC propagates. Reader (not
# Contributor) is intentional — pipelines should READ raw, WRITE
# to cleansed/curated, and the write-grants get attached when the
# write-side pipelines land.
resource "azurerm_role_assignment" "adf_datalake_reader" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
}
