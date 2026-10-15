# Keyless access for the Container App's managed identity.

# Cosmos data plane: the built-in "Cosmos DB Built-in Data Contributor"
# role (fixed definition id ...0002) grants read/write on documents but
# NOT control-plane rights — it can't change the account, drop containers
# or read keys.
resource "azurerm_cosmosdb_sql_role_assignment" "api_data_contributor" {
  resource_group_name = module.resource_group.name
  account_name        = azurerm_cosmosdb_account.portal.name
  role_definition_id  = "${azurerm_cosmosdb_account.portal.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_container_app.portal.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.portal.id
}

# AcrPull for the same identity is granted through the registry module
# (container_apps.tf, role_assignments.portal_pull).
