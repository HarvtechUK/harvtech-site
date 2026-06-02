terraform {
  backend "azurerm" {
    resource_group_name  = "rg-platform-prd-uks-01"
    storage_account_name = "stplatformtfstateuks01"
    container_name       = "tfstate"
    key                  = "data-platform.tfstate"
    use_azuread_auth     = true
  }
}
