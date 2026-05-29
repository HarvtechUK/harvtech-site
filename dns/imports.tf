# Declarative imports for resources that pre-existed Terraform management.
# Terraform 1.5+ evaluates these during plan: if the resource is already in
# state, the import block is a no-op; otherwise it imports by ID and the
# resulting plan should show no changes (modulo tags / drift).
#
# Once first apply completes and state contains these resources, the import
# blocks are kept here as living documentation of where each came from.

import {
  to = azurerm_dns_zone.harvtech_co_uk
  id = "/subscriptions/94e0d891-0e55-48d7-89e4-00ac3211ac44/resourceGroups/rg-dns-prd-uks-01/providers/Microsoft.Network/dnsZones/harvtech.co.uk"
}

import {
  to = azurerm_dns_mx_record.apex
  id = "/subscriptions/94e0d891-0e55-48d7-89e4-00ac3211ac44/resourceGroups/rg-dns-prd-uks-01/providers/Microsoft.Network/dnsZones/harvtech.co.uk/MX/@"
}

import {
  to = azurerm_dns_txt_record.spf
  id = "/subscriptions/94e0d891-0e55-48d7-89e4-00ac3211ac44/resourceGroups/rg-dns-prd-uks-01/providers/Microsoft.Network/dnsZones/harvtech.co.uk/TXT/@"
}

import {
  to = azurerm_dns_cname_record.autodiscover
  id = "/subscriptions/94e0d891-0e55-48d7-89e4-00ac3211ac44/resourceGroups/rg-dns-prd-uks-01/providers/Microsoft.Network/dnsZones/harvtech.co.uk/CNAME/autodiscover"
}
