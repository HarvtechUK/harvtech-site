# Container Apps hosting for the FastAPI portal (portal/).
#
# One container, built from portal/ and pushed to the registry below by
# the deploy workflow. It runs in a Container Apps Environment, scales to
# zero when idle, and reaches Cosmos with its managed identity — no keys
# anywhere, matching the rest of this repo.

resource "azurerm_container_registry" "portal" {
  name                = module.naming.container_registry
  resource_group_name = azurerm_resource_group.portal.name
  location            = azurerm_resource_group.portal.location
  sku                 = "Basic"

  # No admin user: the Container App pulls images with its managed
  # identity (AcrPull role in rbac.tf), so there are no registry
  # username/password credentials to leak.
  admin_enabled = false

  tags = module.tags.tags
}

resource "azurerm_container_app_environment" "portal" {
  name                       = module.naming.container_app_environment
  resource_group_name        = azurerm_resource_group.portal.name
  location                   = azurerm_resource_group.portal.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.portal.id

  tags = module.tags.tags
}

resource "azurerm_container_app" "portal" {
  name                         = module.naming.container_app
  container_app_environment_id = azurerm_container_app_environment.portal.id
  resource_group_name          = azurerm_resource_group.portal.name
  revision_mode                = "Single"

  # System-assigned identity: one principal used both to pull from ACR
  # and to read/write Cosmos (data-plane RBAC). No secrets.
  identity {
    type = "SystemAssigned"
  }

  # Authenticate to our registry using that managed identity.
  registry {
    server   = azurerm_container_registry.portal.login_server
    identity = "System"
  }

  ingress {
    external_enabled = true
    target_port      = 8000 # uvicorn listens here inside the container
    transport        = "auto"

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
    # CI owns the running image tag; Terraform owns everything else about
    # the app. Without this, every plan after a deploy would try to reset
    # the image back to the placeholder.
    ignore_changes = [template[0].container[0].image]
  }

  tags = module.tags.tags
}
