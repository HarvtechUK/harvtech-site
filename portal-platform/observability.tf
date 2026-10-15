# Shared observability for the portal. The Container Apps Environment
# streams container stdout/stderr into this Log Analytics workspace;
# Application Insights captures app-level telemetry (its connection
# string is passed to the container as an env var in container_apps.tf).

resource "azurerm_log_analytics_workspace" "portal" {
  name                = module.naming.log_analytics_workspace
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = module.tags.tags
}

resource "azurerm_application_insights" "api" {
  name                = module.naming.application_insights
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.portal.id

  tags = module.tags.tags
}
