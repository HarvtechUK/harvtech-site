# Cross-stack reference to the site stack's Terraform state. The dns/ stack
# needs Front Door details (endpoint ID, validation tokens) that are owned by
# the site stack. Both stacks share the same Azure backend; the SP managing
# this stack has Storage Blob Data Contributor on the state SA so it can read
# the other stack's blob too.
data "terraform_remote_state" "site" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-platform-prd-uks-01"
    storage_account_name = "stplatformtfstateuks01"
    container_name       = "tfstate"
    key                  = "site.tfstate"
  }
}

# --- Apex (harvtech.co.uk) ---

# Azure DNS apex alias to Front Door. DNS doesn't allow CNAMEs at the apex,
# so Azure exposes target_resource_id on A records — Azure DNS dynamically
# resolves it to the current Front Door anycast IP at query time.
resource "azurerm_dns_a_record" "apex_alias" {
  name                = "@"
  zone_name           = azurerm_dns_zone.harvtech_co_uk.name
  resource_group_name = data.azurerm_resource_group.dns.name
  ttl                 = 3600
  target_resource_id  = data.terraform_remote_state.site.outputs.frontdoor_endpoint_id

  tags = var.tags
}

# TXT for Front Door custom-domain ownership validation (apex).
# Removed automatically once we drop the FD custom domain; safe to leave
# in place after validation completes.
resource "azurerm_dns_txt_record" "apex_dnsauth" {
  name                = "_dnsauth"
  zone_name           = azurerm_dns_zone.harvtech_co_uk.name
  resource_group_name = data.azurerm_resource_group.dns.name
  ttl                 = 3600

  record {
    value = data.terraform_remote_state.site.outputs.apex_validation_token
  }

  tags = var.tags
}

# --- www (www.harvtech.co.uk) — redirects to apex via FD rules engine ---

resource "azurerm_dns_cname_record" "www" {
  name                = "www"
  zone_name           = azurerm_dns_zone.harvtech_co_uk.name
  resource_group_name = data.azurerm_resource_group.dns.name
  ttl                 = 3600
  record              = data.terraform_remote_state.site.outputs.frontdoor_endpoint_hostname

  tags = var.tags
}

resource "azurerm_dns_txt_record" "www_dnsauth" {
  name                = "_dnsauth.www"
  zone_name           = azurerm_dns_zone.harvtech_co_uk.name
  resource_group_name = data.azurerm_resource_group.dns.name
  ttl                 = 3600

  record {
    value = data.terraform_remote_state.site.outputs.www_validation_token
  }

  tags = var.tags
}
