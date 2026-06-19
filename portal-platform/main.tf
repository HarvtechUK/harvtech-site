resource "azurerm_resource_group" "portal" {
  name     = module.naming.resource_group
  location = var.location
  tags     = module.tags.tags
}
