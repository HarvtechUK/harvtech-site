# State moves for adopting shared modules. Each block maps a resource's
# old address to its address inside the module, so adoption is a state
# rename only: the plan must show 0 to add, 0 to change, 0 to destroy.
# Without these, Terraform would destroy the live resource and recreate
# it inside the module.

# --- Root → modules/resource-group ---

moved {
  from = azurerm_resource_group.portal
  to   = module.resource_group.azurerm_resource_group.workload
}

# --- Root → modules/container-registry and modules/container-app-environment ---

moved {
  from = azurerm_container_registry.portal
  to   = module.container_registry.azurerm_container_registry.workload
}

moved {
  from = azurerm_role_assignment.portal_acr_pull
  to   = module.container_registry.azurerm_role_assignment.workload["portal_pull"]
}

moved {
  from = azurerm_container_app_environment.portal
  to   = module.container_app_environment.azurerm_container_app_environment.workload
}
