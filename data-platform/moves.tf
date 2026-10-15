# State moves for adopting shared modules. Each block maps a resource's
# old address to its address inside the module, so adoption is a state
# rename only: the plan must show 0 to add, 0 to change, 0 to destroy.
# Without these, Terraform would destroy the live resource and recreate
# it inside the module.

# --- Root → modules/resource-group ---
# Also retires this stack's generic "this" label for the resource group.

moved {
  from = azurerm_resource_group.this
  to   = module.resource_group.azurerm_resource_group.workload
}
