terraform {
  # 1.9 is the floor because the tag validation references another
  # input variable (cross-variable validation).
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
