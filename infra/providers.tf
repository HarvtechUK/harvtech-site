terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
  # Use Entra ID (AAD) for data-plane storage operations instead of shared
  # access keys. Lets us disable shared_access_key_enabled on storage
  # accounts without breaking Terraform's ability to manage them.
  storage_use_azuread = true
}
