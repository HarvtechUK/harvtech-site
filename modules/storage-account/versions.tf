terraform {
  # 1.9 is the floor because the location, tag and network validations
  # reference other input variables (cross-variable validation).
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
