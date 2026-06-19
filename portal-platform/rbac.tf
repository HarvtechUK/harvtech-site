# Cosmos data-plane access for the Function App's managed identity —
# the "no keys anywhere" mechanism. The built-in Cosmos SQL role
# "Cosmos DB Built-in Data Contributor" (fixed definition id ...0002)
# grants read/write on documents but NOT control-plane rights (it can't
# change the account, delete containers, or read keys).
resource "azurerm_cosmosdb_sql_role_assignment" "api_data_contributor" {
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  role_definition_id  = "${azurerm_cosmosdb_account.this.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_linux_function_app.api.identity[0].principal_id
  scope               = azurerm_cosmosdb_account.this.id
}
