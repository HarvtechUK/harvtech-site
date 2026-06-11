# The DNS resource group is shared with other personal projects
# (alultech.com, nuveotech.com). We reference it via data source and
# only manage the harvtech.co.uk zone + records from this state.
data "azurerm_resource_group" "dns" {
  name = var.dns_resource_group_name
}

resource "azurerm_dns_zone" "harvtech_co_uk" {
  name                = "harvtech.co.uk"
  resource_group_name = data.azurerm_resource_group.dns.name
  tags                = module.tags.tags
}

# --- Microsoft 365 mail records ---
# Apex MX pointing at Exchange Online.
resource "azurerm_dns_mx_record" "apex" {
  name                = "@"
  zone_name           = azurerm_dns_zone.harvtech_co_uk.name
  resource_group_name = data.azurerm_resource_group.dns.name
  ttl                 = 3600

  record {
    preference = 0
    exchange   = "harvtech-co-uk.mail.protection.outlook.com"
  }

  tags = module.tags.tags
}

# SPF for Exchange Online.
resource "azurerm_dns_txt_record" "spf" {
  name                = "@"
  zone_name           = azurerm_dns_zone.harvtech_co_uk.name
  resource_group_name = data.azurerm_resource_group.dns.name
  ttl                 = 3600

  record {
    value = "v=spf1 include:spf.protection.outlook.com -all"
  }

  tags = module.tags.tags
}

# Outlook autodiscover.
resource "azurerm_dns_cname_record" "autodiscover" {
  name                = "autodiscover"
  zone_name           = azurerm_dns_zone.harvtech_co_uk.name
  resource_group_name = data.azurerm_resource_group.dns.name
  ttl                 = 3600
  record              = "autodiscover.outlook.com"

  tags = module.tags.tags
}
