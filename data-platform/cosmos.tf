# Cosmos DB account with the SQL (Core) API — the most-common Cosmos
# flavour. Free tier (1000 RU/s + 25 GB free for life) is enabled by
# default via var.enable_cosmos_free_tier. Microsoft caps this to ONE
# account per subscription, ever; flip the flag if it's already in use.
resource "azurerm_cosmosdb_account" "this" {
  name                = local.cosmos_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  offer_type = "Standard"
  kind       = "GlobalDocumentDB" # Core (SQL) API

  free_tier_enabled = var.enable_cosmos_free_tier

  # Session is the default and right for most read-your-writes scenarios.
  # Stronger consistencies (BoundedStaleness, Strong) cost more RU and
  # constrain multi-region setups we don't have.
  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.this.location
    failover_priority = 0
  }

  # Public network access on for portfolio demo simplicity. A real
  # client engagement would use private endpoints + VNet integration.
  public_network_access_enabled = true

  # Local auth (master keys / connection strings) is disabled — anyone
  # using this DB has to come via Entra. Matches the discipline applied
  # to the site storage account.
  local_authentication_disabled = true

  tags = var.tags
}

# Databases + containers driven by var.cosmos_databases. The nested
# map shape means we need a separate resource per LEVEL (database
# then container) but each is a for_each — adding a new database
# or a new container under an existing one is a tfvars edit.
resource "azurerm_cosmosdb_sql_database" "this" {
  for_each = var.cosmos_databases

  name                = each.key
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
}

# Flatten the (database -> containers) shape into a single map keyed
# by "<db>/<container>" so we can drive a single for_each. Each entry
# carries the parent database name forward.
locals {
  cosmos_containers = merge([
    for db_name, db in var.cosmos_databases : {
      for container_name, container in db.containers :
      "${db_name}/${container_name}" => {
        database_name      = db_name
        container_name     = container_name
        partition_key_path = container.partition_key_path
      }
    }
  ]...)
}

resource "azurerm_cosmosdb_sql_container" "this" {
  for_each = local.cosmos_containers

  name                = each.value.container_name
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.this[each.value.database_name].name
  partition_key_paths = [each.value.partition_key_path]
}
