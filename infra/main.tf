data "azurerm_client_config" "current" {}

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

  # Lock the storage account down to only the specific FD profile in
  # front of it — anyone bypassing FD (and the WAF) by hitting the
  # *.web.core.windows.net hostname directly gets denied. Closes
  # Trivy AZU-0012 (the one CRITICAL).
  #
  # bypass = ["AzureServices"] keeps the AzureServices trusted-list
  # exception (Azure Monitor, Backup, etc).
  #
  # `private_link_access` here is misleadingly named — it's actually
  # the "resource instance rule" feature, NOT Private Link (which would
  # need Premium FD). It tells the SA's network ACL to grant access to
  # this specific Front Door profile's backplane.
  #
  # GitHub Actions runners are NOT Azure services and don't have a
  # stable IP, so the deploy workflow temporarily adds the runner's
  # public IP to ip_rules via `az storage account network-rule add`
  # before doing any data-plane operation, and removes it after.
  # `lifecycle.ignore_changes` below stops Terraform fighting those
  # transient additions.
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]

    private_link_access {
      endpoint_resource_id = azurerm_cdn_frontdoor_profile.this.id
      endpoint_tenant_id   = data.azurerm_client_config.current.tenant_id
    }
  }

  lifecycle {
    ignore_changes = [
      # CI workflow adds/removes the runner IP transiently around
      # data-plane operations. See deploy.yml.
      network_rules[0].ip_rules,
    ]
  }

  tags = var.tags
}
