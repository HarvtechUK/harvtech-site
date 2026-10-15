# A Container Apps environment: the shared boundary (network, logging)
# that one or more container apps run inside. The one opinion that is not
# negotiable is logging: every environment sends its apps' logs to a Log
# Analytics workspace, so there is always somewhere to investigate from.
#
# VNet integration is optional. Without it, the environment runs on
# Microsoft-managed networking: apps can only reach public endpoints, and
# anything they depend on (Key Vault, Cosmos, a registry) has to accept
# public traffic. That is the trade-off the portal makes today.

resource "azurerm_container_app_environment" "workload" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  log_analytics_workspace_id = var.log_analytics_workspace_id

  # The provider only accepts internal_load_balancer_enabled alongside a
  # subnet, even when it is false, so it is passed only with one.
  infrastructure_subnet_id       = var.infrastructure_subnet_id
  internal_load_balancer_enabled = var.infrastructure_subnet_id == null ? null : var.internal_load_balancer_enabled

  lifecycle {
    precondition {
      condition     = !var.internal_load_balancer_enabled || var.infrastructure_subnet_id != null
      error_message = "internal_load_balancer_enabled needs infrastructure_subnet_id: an internal-only environment has to live in a VNet."
    }
  }
}
