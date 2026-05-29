terraform {
  backend "azurerm" {
    resource_group_name  = "rg-platform-prd-uks-01"
    storage_account_name = "stplatformtfstateuks01"
    container_name       = "tfstate"
    key                  = "site.tfstate"
    # use_oidc is read from ARM_USE_OIDC env var (set in CI, omitted locally).
    # Local runs auth via `az login`; CI auths via GitHub OIDC federation.
  }
}
