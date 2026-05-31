terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.5"
    }
  }
}

# The azuread provider talks to Microsoft Graph for everything in this
# stack (CA policies, users, named locations). It auths via the same
# OIDC federation pattern as azurerm, but uses a separately-bootstrapped
# service principal (sp-github-harvtech-identity) that only has the
# Microsoft Graph App permissions it needs — Policy.Read.All,
# Policy.ReadWrite.ConditionalAccess, User.Read.All.
#
# Separation of duties: the app-infra SP (sp-github-harvtech-site) has
# Azure RBAC for ARM resources but NO Graph permissions; this SP has
# Graph permissions but no Azure RBAC. A compromise of either bounds
# the blast radius accordingly.
provider "azuread" {
  use_oidc = true
}
