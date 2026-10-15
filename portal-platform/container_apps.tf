# Container Apps hosting for the FastAPI portal (portal/).
#
# One container, built from portal/ and pushed to the registry below by
# the deploy workflow. It runs in a Container Apps environment, scales to
# zero when idle, and reaches the registry, Key Vault and Cosmos with its
# managed identity: no keys, passwords or secret values anywhere in this
# stack or its state.

# Images are pulled by the app's managed identity (AcrPull below) and
# pushed by CI (AcrPush, granted at bootstrap). No admin user, no
# anonymous pulls: both are fixed in modules/container-registry.
module "container_registry" {
  source              = "../modules/container-registry"
  name                = module.naming.container_registry
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = module.tags.tags

  # Basic (~£4/mo) and therefore public: one first-party image, pulled by
  # one identity. The Premium-only features (private access, retention,
  # content trust) are suppressed with that reasoning in .checkov.yaml.
  sku                           = "Basic"
  public_network_access_enabled = true

  role_assignments = {
    portal_pull = {
      role_definition_id_or_name = "AcrPull"
      principal_id               = module.container_app.principal_id
      principal_type             = "ServicePrincipal"
    }
  }
}

# Not VNet-integrated, so the portal reaches Cosmos and Key Vault over
# their public (Entra RBAC-protected) endpoints. That is the deferred
# private-networking trade-off recorded across this stack.
module "container_app_environment" {
  source                     = "../modules/container-app-environment"
  name                       = module.naming.container_app_environment
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  tags                       = module.tags.tags
  log_analytics_workspace_id = azurerm_log_analytics_workspace.portal.id
}

# The portal app. Terraform owns its whole configuration except the
# running image, which the deploy workflow ships. Secrets are Key Vault
# references, so their values never pass through Terraform, its state,
# or the pipeline; they live only in the vault (key_vault.tf) and are
# set by an operator when rotating.
locals {
  # Known before the app exists (app name + environment domain), so the
  # redirect URI needs no reference back to the app itself.
  portal_hostname = "${module.naming.container_app}.${module.container_app_environment.default_domain}"
}

module "container_app" {
  source                       = "../modules/container-app"
  name                         = module.naming.container_app
  resource_group_name          = module.resource_group.name
  container_app_environment_id = module.container_app_environment.id
  tags                         = module.tags.tags

  # Bootstrap image only; the deploy workflow owns the running image.
  image          = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
  container_name = "portal"
  cpu            = 0.25
  memory         = "0.5Gi"
  min_replicas   = 0 # scale to zero when idle
  max_replicas   = 2

  target_port              = 8000
  external_ingress_enabled = true
  health_probe_path        = "/healthz"

  registry = {
    server = module.container_registry.login_server
  }

  env = {
    COSMOS_ENDPOINT                       = azurerm_cosmosdb_account.portal.endpoint
    COSMOS_DATABASE                       = azurerm_cosmosdb_sql_database.portal.name
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.api.connection_string
    ENTRA_CLIENT_ID                       = var.portal_entra_client_id
    ENTRA_AUTHORITY                       = "https://login.microsoftonline.com/organizations"
    ENTRA_REDIRECT_URI                    = "https://${local.portal_hostname}/auth/callback"
  }

  secrets = {
    entra-client-secret = { key_vault_secret_id = "${module.key_vault.vault_uri}secrets/entra-client-secret" }
    session-secret      = { key_vault_secret_id = "${module.key_vault.vault_uri}secrets/session-secret" }
  }

  secret_env = {
    ENTRA_CLIENT_SECRET = "entra-client-secret"
    SESSION_SECRET      = "session-secret"
  }
}
