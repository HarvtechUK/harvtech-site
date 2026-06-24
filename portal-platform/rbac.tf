# Keyless access for the Container App's managed identity.

# Cosmos data plane: the built-in "Cosmos DB Built-in Data Contributor"
# role (fixed definition id ...0002) grants read/write on documents but
# NOT control-plane rights — it can't change the account, drop containers
# or read keys.
resource "azurerm_cosmosdb_sql_role_assignment" "api_data_contributor" {
  resource_group_name = azurerm_resource_group.portal.name
  account_name        = azurerm_cosmosdb_account.portal.name
  role_definition_id  = "${azurerm_cosmosdb_account.portal.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_container_app.portal.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.portal.id
}

# Pull images from our own registry with the same managed identity, so
# the Container App needs no registry username/password.
resource "azurerm_role_assignment" "portal_acr_pull" {
  scope                = azurerm_container_registry.portal.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.portal.identity[0].principal_id
}
