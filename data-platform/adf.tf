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

  tags = module.tags.tags
}

# NOTE: ADF's managed identity should eventually be granted Storage Blob
# Data Reader on the datalake so future pipelines can authenticate via
# Entra rather than connection strings. That role assignment is
# deliberately NOT in this stack — the data-platform SP has Contributor
# at subscription scope, which lacks the Microsoft.Authorization/
# roleAssignments/write permission required to manage RBAC.
#
# The right fix is to grant the SP User Access Administrator scoped to
# rg-harvtech-data-prd-uks-01 (so it can manage roles within its own
# blast radius but nowhere else), then re-introduce this resource:
#
#   resource "azurerm_role_assignment" "adf_datalake_reader" {
#     scope                = azurerm_storage_account.datalake.id
#     role_definition_name = "Storage Blob Data Reader"
#     principal_id         = azurerm_data_factory.this.identity[0].principal_id
#   }
#
# Tracked as a follow-up — same RBAC tape-fix backlog item as the
# Storage Blob Data Contributor grant on the site SA.
