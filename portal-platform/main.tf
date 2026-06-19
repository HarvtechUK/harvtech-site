resource "azurerm_resource_group" "this" {
  name     = module.naming.resource_group
  location = var.location
  tags     = module.tags.tags
}
