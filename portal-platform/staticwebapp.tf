# Static Web App serves the portal UI and provides authentication at the
# edge (wired to Entra External ID in Phase 2). Standard SKU is required
# for the linked Function App backend.
#
# Region note: Static Web Apps are only offered in a handful of regions
# and uksouth is NOT one of them — westeurope is the nearest. The rest
# of the stack stays in uksouth; only the SWA control resource lives in
# westeurope. (The edge is global regardless.)
resource "azurerm_static_web_app" "portal" {
  name                = module.naming.static_web_app
  resource_group_name = azurerm_resource_group.portal.name
  location            = "westeurope"
  sku_tier            = var.static_web_app_sku
  sku_size            = var.static_web_app_sku

  tags = module.tags.tags
}

# Custom domain (portal.harvtech.co.uk) is added in a sequenced
# follow-up once this stack is applied and its default hostname is in
# remote state: dns/ creates the CNAME first, then the
# azurerm_static_web_app_custom_domain resource here validates against
# it. Bundling it now would fail the first apply — there'd be no CNAME
# to validate. var.portal_hostname is already defined for that step.
