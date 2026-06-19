# Dedicated Cosmos account for the portal — separate from the
# data-platform's analytics-demo account so real client PII and
# financial records have their own blast radius, backups, and access
# policy (HLD decision D1).
#
# Serverless: pay-per-request, no provisioned RU/s to pay for at idle.
# Right for a low-traffic line-of-business app. (Serverless and free
# tier are mutually exclusive; free tier is already claimed by the
# data-platform account anyway.)
resource "azurerm_cosmosdb_account" "portal" {
  name                = module.naming.cosmosdb_account
  resource_group_name = azurerm_resource_group.portal.name
  location            = azurerm_resource_group.portal.location

  offer_type = "Standard"
  kind       = "GlobalDocumentDB" # Core (SQL) API

  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.portal.location
    failover_priority = 0
  }

  # No keys: every caller authenticates via Entra. The Function App
  # reaches this account through its managed identity + a data-plane
  # role assignment (see rbac.tf).
  local_authentication_disabled = true

  # Fresh account, so double-encryption at rest is free to set at create
  # time (unlike the site SA, which had to be retrofitted).
  public_network_access_enabled = true

  tags = module.tags.tags
}

resource "azurerm_cosmosdb_sql_database" "portal" {
  name                = "portal"
  resource_group_name = azurerm_resource_group.portal.name
  account_name        = azurerm_cosmosdb_account.portal.name
}

# clients / users / engagements / timesheets — see docs/architecture/portal-hld.md.
# engagements & timesheets partition by /clientId for per-tenant isolation.
resource "azurerm_cosmosdb_sql_container" "portal" {
  for_each = var.portal_containers

  name                = each.key
  resource_group_name = azurerm_resource_group.portal.name
  account_name        = azurerm_cosmosdb_account.portal.name
  database_name       = azurerm_cosmosdb_sql_database.portal.name
  partition_key_paths = [each.value.partition_key_path]
}
