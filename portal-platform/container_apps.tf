# Container Apps hosting for the FastAPI portal (portal/).
#
# One container, built from portal/ and pushed to the registry below by
# the deploy workflow. It runs in a Container Apps Environment, scales to
# zero when idle, and reaches Cosmos with its managed identity — no keys
# anywhere, matching the rest of this repo.

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
      principal_id               = azurerm_container_app.portal.identity[0].principal_id
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

resource "azurerm_container_app" "portal" {
  name                         = module.naming.container_app
  container_app_environment_id = module.container_app_environment.id
  resource_group_name          = module.resource_group.name
  revision_mode                = "Single"

  # System-assigned identity: one principal used both to pull from ACR
  # and to read/write Cosmos (data-plane RBAC). No secrets.
  identity {
    type = "SystemAssigned"
  }

  # NOTE: no `registry` block here on purpose. If the app is created with
  # a registry configured to pull via this managed identity, Container
  # Apps validates that access during provisioning — but the AcrPull role
  # (rbac.tf) can only be granted AFTER the identity exists, so the create
  # deadlocks and times out. Instead the bootstrap runs the public
  # placeholder image (no registry needed), and the deploy workflow runs
  # `az containerapp registry set --identity system` once AcrPull is in
  # place. `registry` is in ignore_changes below so Terraform leaves that
  # deploy-managed config alone.

  ingress {
    external_enabled = true
    # 80 matches the bootstrap placeholder (containerapps-helloworld listens
    # on 80). target_port MUST match the running container's port or the
    # revision never goes healthy and provisioning times out. The deploy
    # workflow flips this to 8000 (where our uvicorn listens) when it ships
    # the real image; ignore_changes below stops Terraform reverting it.
    target_port = 80
    transport   = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0 # scale to zero when idle — nothing to pay at rest
    max_replicas = 2

    container {
      name = "portal"
      # Placeholder for the first apply — our image isn't in ACR yet.
      # The deploy workflow builds portal/, pushes it to ACR, and updates
      # the app to that image. The lifecycle block hands the image tag to
      # CI, so Terraform stops trying to manage it after that.
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "COSMOS_ENDPOINT"
        value = azurerm_cosmosdb_account.portal.endpoint
      }
      env {
        name  = "COSMOS_DATABASE"
        value = azurerm_cosmosdb_sql_database.portal.name
      }
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.api.connection_string
      }
    }
  }

  lifecycle {
    # CI owns the running image tag AND the ingress port (it flips 80→8000
    # when shipping the real image); Terraform owns everything else. Without
    # this, every plan after a deploy would try to reset them.
    #
    # CI also owns the env list and secrets after the first apply. The
    # deploy workflow adds the ENTRA_* sign-in settings and SESSION_SECRET
    # (values from GitHub secrets, so they never enter Terraform state).
    # Before env and secret were listed here, any apply of this stack
    # would have deleted them. Terraform still seeds the COSMOS_* and
    # App Insights variables above when the app is created, but later
    # edits to them need a deploy (or a one-off az containerapp update),
    # because env is a single list and cannot be part-ignored. The app
    # also refuses to start with Cosmos configured and no sign-in
    # (portal/app/config.py), so a lost variable fails closed.
    ignore_changes = [
      template[0].container[0].image,
      template[0].container[0].env,
      ingress[0].target_port,
      registry,
      secret,
    ]
  }

  tags = module.tags.tags
}
