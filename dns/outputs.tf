output "zone_name" {
  value       = azurerm_dns_zone.harvtech_co_uk.name
  description = "Name of the public DNS zone"
}

output "name_servers" {
  value       = azurerm_dns_zone.harvtech_co_uk.name_servers
  description = "Authoritative name servers (read these into the domain registrar)"
}

output "zone_id" {
  value       = azurerm_dns_zone.harvtech_co_uk.id
  description = "Resource ID of the zone, for cross-stack consumption"
}
