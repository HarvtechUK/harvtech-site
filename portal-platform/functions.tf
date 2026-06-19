# The portal API runs as a Function App in OUR subscription (not SWA's
# managed Functions) specifically so it can carry a system-assigned
# managed identity and reach Cosmos via data-plane RBAC — no keys.

# Backing storage for the Functions runtime (AzureWebJobsStorage). This
# is the runtime's own content/lease store, NOT client data — client
# data lives in Cosmos, reached via managed identity.
#
# NOTE: the Functions runtime on the Consumption plan still needs a key
# for AzureWebJobsStorage, so shared_access_key_enabled stays true on
# THIS account only. It holds no business data. Revisit with the Flex
# Consumption plan, which supports a managed-identity runtime store.
resource "azurerm_storage_account" "functions" {
  name                            = module.naming.storage_account
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  # Soft-delete blobs and containers for 7 days — cheap insurance on the
  # runtime store. Matches the site SA. (CKV2_AZURE_38)
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  # Cap any SAS lifetime even though we don't mint SAS tokens — defence
  # in depth. Matches the site SA. (CKV2_AZURE_41)
  sas_policy {
    expiration_period = "00.01:00:00" # 1 hour max
    expiration_action = "Log"
  }

  tags = module.tags.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = module.naming.log_analytics_workspace
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = module.tags.tags
}

resource "azurerm_application_insights" "this" {
  name                = module.naming.application_insights
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.this.id

  tags = module.tags.tags
}

# Linux Consumption plan (Y1) — pay-per-execution, ~£0 at this volume.
resource "azurerm_service_plan" "this" {
  name                = module.naming.app_service_plan
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Linux"
  sku_name            = "Y1"

  tags = module.tags.tags
}

resource "azurerm_linux_function_app" "api" {
  name                = module.naming.function_app
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  service_plan_id     = azurerm_service_plan.this.id

  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key

  # System-assigned managed identity — the principal granted Cosmos
  # data-plane access in rbac.tf.
  identity {
    type = "SystemAssigned"
  }

  https_only = true

  site_config {
    application_insights_connection_string = azurerm_application_insights.this.connection_string
    ftps_state                             = "Disabled"
    minimum_tls_version                    = "1.2"

    application_stack {
      node_version = "20"
    }
  }

  app_settings = {
    # Cosmos endpoint only — no key. The SDK authenticates with the
    # function's managed identity (DefaultAzureCredential).
    COSMOS_ENDPOINT = azurerm_cosmosdb_account.this.endpoint
    COSMOS_DATABASE = azurerm_cosmosdb_sql_database.portal.name
  }

  tags = module.tags.tags
}
