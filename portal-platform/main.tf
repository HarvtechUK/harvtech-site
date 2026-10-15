# Resource group for the portal stack: UK-region, tag and RBAC
# guardrails come from modules/resource-group.
module "resource_group" {
  source   = "../modules/resource-group"
  name     = module.naming.resource_group
  location = var.location
  tags     = module.tags.tags
}
