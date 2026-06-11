# Azure Databricks workspace. The workspace itself has NO ongoing
# cost — cost only hits when clusters spin up (DBU/hr + underlying
# VM time). We're deliberately not creating clusters or cluster
# policies here; the workspace exists as a portfolio demonstration
# of the IaC pattern plus a clean place to spin up notebooks
# manually if needed.
#
# SKU: Standard. Premium adds Unity Catalog and finer-grained RBAC
# which would be the right choice for a multi-team environment;
# Standard is the right choice when there's one engineer.
#
# Databricks creates its own managed resource group (containing the
# worker VMs, NSG, storage, etc.) when the workspace is provisioned.
# That RG's name is pinned via managed_resource_group_name so it
# doesn't get an auto-generated GUID suffix on every recreate.
resource "azurerm_databricks_workspace" "this" {
  name                = local.databricks_ws
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = var.databricks_sku

  managed_resource_group_name = local.databricks_rg

  # Public network access on for portfolio simplicity. A real client
  # engagement would use VNet injection + Private Link to the control
  # plane.
  public_network_access_enabled = true

  tags = module.tags.tags
}
