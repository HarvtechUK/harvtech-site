terraform {
  backend "azurerm" {
    resource_group_name  = "rg-platform-prd-uks-01"
    storage_account_name = "stplatformtfstateuks01"
    container_name       = "tfstate"
    key                  = "identity.tfstate"
    # use_oidc is read from ARM_USE_OIDC env var (set in CI, omitted locally).
    # NOTE: the backend uses azurerm-style auth (Azure Storage), so the SP
    # for THIS stack also needs Storage Blob Data Contributor on the
    # platform state SA. That's granted out of band — see bootstrap docs.
  }
}
