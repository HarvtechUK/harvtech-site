# Secrets for the portal (the Entra client secret and the session
# signing key). Terraform creates the vault and grants access but never
# writes or reads a secret value, so no value can reach Terraform state.
# Values are set by an operator when rotating; see the "Rotating a
# secret" section of modules/key-vault/README.md.

data "azurerm_client_config" "current" {}

module "key_vault" {
  source                     = "../modules/key-vault"
  name                       = module.naming.key_vault
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  tags                       = module.tags.tags
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.portal.id

  # Public on purpose, protected by Entra RBAC. The Container Apps
  # environment is not VNet-integrated, and Container Apps is not one of
  # Key Vault's trusted services, so a private or firewalled vault would
  # lock the portal out of its own secrets. The productionisation path
  # (VNet-integrated environment plus a private endpoint) is the same one
  # the rest of this stack defers; see the matching suppressions in
  # .checkov.yaml and .trivyignore.
  public_network_access_enabled = true

  role_assignments = {
    # The portal reads its secrets at revision start with its managed
    # identity. Secrets User is read-only on secret values: it cannot
    # list keys, change secrets or manage the vault.
    portal_secrets_read = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = azurerm_container_app.portal.identity[0].principal_id
      principal_type             = "ServicePrincipal"
    }
  }
}
