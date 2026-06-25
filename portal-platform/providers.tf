terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
  # Entra ID for data-plane storage operations rather than shared keys —
  # matches the discipline across the rest of this repo.
  storage_use_azuread = true
}
