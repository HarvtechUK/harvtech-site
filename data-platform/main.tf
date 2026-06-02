resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

# --- ADLS Gen2 storage account ---
# is_hns_enabled = true is what makes this a Data Lake Storage Gen2
# account rather than a normal Blob Storage account: hierarchical
# namespace, POSIX-style ACLs, and the dfs.core.windows.net endpoint
# for Spark/Databricks-style filesystem access.
#
# Created fresh, so unlike the site SA we CAN set
# infrastructure_encryption_enabled = true at create time without a
# replacement-and-RBAC-redo dance.
resource "azurerm_storage_account" "datalake" {
  name                = local.datalake_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  is_hns_enabled                  = true # ADLS Gen2 = HNS on
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  public_network_access_enabled   = true
  # Default-to-Entra-auth for any client SDK that doesn't specify an
  # auth flow. Belt-and-braces alongside shared_access_key_enabled=false.
  default_to_oauth_authentication = true

  # Double-encrypt at rest. Free flag, no operational cost.
  infrastructure_encryption_enabled = true

  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  sas_policy {
    expiration_period = "00.01:00:00"
    expiration_action = "Log"
  }

  tags = var.tags
}

# Medallion layers — raw (bronze), cleansed (silver), curated (gold).
# Adding a new layer = one entry in var.lakehouse_layers.
resource "azurerm_storage_container" "lakehouse" {
  for_each = toset(var.lakehouse_layers)

  name                  = each.value
  storage_account_id    = azurerm_storage_account.datalake.id
  container_access_type = "private"
}
