terraform {
  backend "azurerm" {
    resource_group_name  = "rg-platform-prd-uks-01"
    storage_account_name = "stplatformtfstateuks01"
    container_name       = "tfstate"
    key                  = "identity.tfstate"
    # use_oidc is read from ARM_USE_OIDC env var (set in CI, omitted locally).
    #
    # use_azuread_auth tells the backend to talk to Storage's data plane via
    # Entra ID auth, skipping the listKeys control-plane call. The identity
    # SP only has Storage Blob Data Contributor (data plane), so without
    # this flag the backend tries listKeys and gets 403 AuthorizationFailed.
    # Modern recommended pattern — same outcome with strictly less privilege.
    use_azuread_auth = true
  }
}
