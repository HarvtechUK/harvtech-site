resource "azurerm_resource_group" "site" {
  name     = local.rg_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "site" {
  name                            = local.storage_name
  resource_group_name             = azurerm_resource_group.site.name
  location                        = azurerm_resource_group.site.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  # NOTE: infrastructure_encryption_enabled = true (Trivy AZU-0061) is
  # deliberately omitted here — it forces SA replacement, which would
  # blow away the SP's manually-granted Storage Blob Data Contributor
  # role assignment and break the deploy-site step. Bundled into the
  # planned "SA modernization" commit that does the AZU-0012 service-tag
  # restriction alongside, with coordinated RBAC re-grant.

  # Disable legacy shared-access keys. The CI/CD deploy step authenticates
  # via Entra (`az storage blob upload-batch --auth-mode login`) and the
  # azurerm provider is configured with `storage_use_azuread = true`, so
  # nothing in this stack needs the keys. Closes Checkov CKV2_AZURE_40.
  shared_access_key_enabled = false

  static_website {
    index_document     = "index.html"
    error_404_document = "404.html"
  }

  # Soft-delete: keep deleted blobs and containers for 7 days so an
  # accidental rm or overwrite can be reverted. Cheap insurance; closes
  # Checkov CKV2_AZURE_38.
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  # SAS expiration policy — even though we don't currently issue SAS
  # tokens, enforcing a max lifetime is defence-in-depth so if anything
  # ever does mint a SAS it can't be long-lived. Closes Checkov
  # CKV2_AZURE_41.
  sas_policy {
    expiration_period = "00.01:00:00" # 1 hour max
    expiration_action = "Log"
  }

  # NOTE: there's no `network_rules { default_action = "Deny" }` block
  # here, even though Trivy AZU-0012 wants one. Microsoft's resource
  # instance rule mechanism (`private_link_access` in azurerm) does NOT
  # include Microsoft.Cdn/profiles in its supported resource types —
  # see https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-trusted-azure-services
  # for the list. So a Standard-SKU Front Door has no way to be
  # explicitly allowed when the SA defaults to Deny; locking the
  # storage down would also lock out FD.
  #
  # The supported alternatives are:
  #   - Upgrade to FD Premium and use actual Private Link to origin
  #     (~£200/mo uplift), or
  #   - Replace the storage origin with a service that IS in the
  #     supported list (App Service, AKS workload, etc.)
  #
  # For a portfolio site, neither is justified. AZU-0012 is
  # consciously accepted and suppressed in .trivyignore with this
  # reasoning recorded.

  tags = var.tags
}
